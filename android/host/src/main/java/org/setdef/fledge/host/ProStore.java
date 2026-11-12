// SPDX-FileCopyrightText: 2026 setdef <kerrick@setdef.com>
// SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved

package org.setdef.fledge.host;

import android.app.Activity;
import android.net.Uri;
import android.util.Base64;
import android.util.Log;
import com.android.billingclient.api.AcknowledgePurchaseParams;
import com.android.billingclient.api.BillingClient;
import com.android.billingclient.api.BillingClientStateListener;
import com.android.billingclient.api.BillingFlowParams;
import com.android.billingclient.api.BillingResult;
import com.android.billingclient.api.PendingPurchasesParams;
import com.android.billingclient.api.ProductDetails;
import com.android.billingclient.api.Purchase;
import com.android.billingclient.api.PurchasesUpdatedListener;
import com.android.billingclient.api.QueryProductDetailsParams;
import com.android.billingclient.api.QueryPurchasesParams;
import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.util.List;

/**
 * Buying Pro, with Play Billing. Neither Lota nor LÖVE knows
 * a store, so the game opens a dotpopper-store: URL
 * (Presentation::Storefront) and MainActivity#startActivity hands it here.
 * The answer goes into the file the URL names, the whole state each time,
 * written by renaming a finished file over it, which the game reads a few
 * times a second (ADR-0008; doc/design/store-and-pro.md):
 *
 * <pre>
 *   answer=7          the number of the request this answers
 *   owned=1           whether this player has the product
 *   state=ready       loading, working, ready, pending, cancelled,
 *                     restored, none, failed or unavailable
 *   price=$1.99       the store's own, in the player's currency
 *   receipt=play:J:S  while owned, the purchase's original JSON (J) and
 *                     Play's signature of it (S), each in Base64, which
 *                     the game verifies itself (Receipt::Play)
 * </pre>
 *
 * Only a purchase Play reports as PURCHASED counts as owned, never a
 * pending one, and each is acknowledged, or Play refunds it after three
 * days. "owned" alone grants nothing: the game takes Pro only from the
 * receipt. Owned purchases are asked for first when the game opens the
 * store, before the price, since Play answers them from the Play Store
 * app's cache and the price needs the network; so a launch with no
 * internet still finds Pro (inference: Play Billing's reference does not
 * say so). There is no server, so nothing else checks it. Everything here
 * runs on the main thread: requests are posted to it, and Play Billing
 * calls its listeners on it.
 */
final class ProStore implements PurchasesUpdatedListener {
    private static final String TAG = "DotPopperStore";

    private final Activity activity;
    private final BillingClient client;
    private String productId = "";
    private File file;
    private int number;
    private boolean owned;
    private String receipt = "";
    private String state = "loading";
    private String price = "";
    private ProductDetails details;

    ProStore(Activity activity) {
        this.activity = activity;
        client = BillingClient.newBuilder(activity)
            .setListener(this)
            .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
            .build();
    }

    /** Takes a dotpopper-store: URL; false if it lacks what it needs. */
    boolean handle(Uri uri) {
        String action = uri.getHost();
        String product = uri.getQueryParameter("product");
        String path = uri.getQueryParameter("file");
        String n = uri.getQueryParameter("n");
        if (action == null || product == null || path == null || n == null) {
            return false;
        }
        activity.runOnUiThread(() -> {
            productId = product;
            file = new File(path);
            number = Integer.parseInt(n);
            perform(action);
        });
        return true;
    }

    private void perform(String action) {
        state = "open".equals(action) ? "loading" : "working";
        write();
        connected(() -> {
            switch (action) {
                case "open" -> open();
                case "buy" -> buy();
                case "restore" -> queryOwned(true);
                default -> finish("failed");
            }
        });
    }

    /** Runs next with the billing service connected, or reports it isn't. */
    private void connected(Runnable next) {
        if (client.isReady()) {
            next.run();
            return;
        }
        client.startConnection(new BillingClientStateListener() {
            @Override
            public void onBillingSetupFinished(BillingResult result) {
                activity.runOnUiThread(() -> {
                    if (result.getResponseCode() == BillingClient.BillingResponseCode.OK) {
                        next.run();
                    } else {
                        Log.w(TAG, "billing setup: " + result.getDebugMessage());
                        finish("unavailable");
                    }
                });
            }

            @Override
            public void onBillingServiceDisconnected() {
                Log.i(TAG, "billing service disconnected");
            }
        });
    }

    /** What this player owns first, from Play's cache, then the price. */
    private void open() {
        QueryPurchasesParams params = QueryPurchasesParams.newBuilder()
            .setProductType(BillingClient.ProductType.INAPP)
            .build();
        client.queryPurchasesAsync(params, (result, purchases) -> activity.runOnUiThread(() -> {
            if (result.getResponseCode() == BillingClient.BillingResponseCode.OK) {
                take(purchases);
                write();
            } else {
                Log.w(TAG, "purchases: " + result.getDebugMessage());
            }
            price();
        }));
    }

    private void price() {
        QueryProductDetailsParams params = QueryProductDetailsParams.newBuilder()
            .setProductList(List.of(QueryProductDetailsParams.Product.newBuilder()
                .setProductId(productId)
                .setProductType(BillingClient.ProductType.INAPP)
                .build()))
            .build();
        client.queryProductDetailsAsync(params, (result, found) -> activity.runOnUiThread(() -> {
            List<ProductDetails> list = found.getProductDetailsList();
            if (result.getResponseCode() != BillingClient.BillingResponseCode.OK || list.isEmpty()) {
                Log.w(TAG, "no product details: " + result.getDebugMessage());
                finish("unavailable");
                return;
            }
            details = list.get(0);
            ProductDetails.OneTimePurchaseOfferDetails offer = details.getOneTimePurchaseOfferDetails();
            if (offer != null) {
                price = offer.getFormattedPrice();
            }
            finish("ready");
        }));
    }

    private void buy() {
        if (details == null) {
            finish("failed");
            return;
        }
        BillingFlowParams params = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(List.of(BillingFlowParams.ProductDetailsParams.newBuilder()
                .setProductDetails(details)
                .build()))
            .build();
        BillingResult result = client.launchBillingFlow(activity, params);
        int code = result.getResponseCode();
        if (code == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED) {
            queryOwned(false);
        } else if (code != BillingClient.BillingResponseCode.OK) {
            Log.w(TAG, "billing flow: " + result.getDebugMessage());
            finish("failed");
        }
    }

    @Override
    public void onPurchasesUpdated(BillingResult result, List<Purchase> purchases) {
        int code = result.getResponseCode();
        if (code == BillingClient.BillingResponseCode.OK && purchases != null) {
            take(purchases);
            finish(owned ? "ready" : "pending");
        } else if (code == BillingClient.BillingResponseCode.USER_CANCELED) {
            finish("cancelled");
        } else if (code == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED) {
            queryOwned(false);
        } else {
            Log.w(TAG, "purchase: " + result.getDebugMessage());
            finish("failed");
        }
    }

    private void queryOwned(boolean restoring) {
        QueryPurchasesParams params = QueryPurchasesParams.newBuilder()
            .setProductType(BillingClient.ProductType.INAPP)
            .build();
        client.queryPurchasesAsync(params, (result, purchases) -> activity.runOnUiThread(() -> {
            if (result.getResponseCode() != BillingClient.BillingResponseCode.OK) {
                Log.w(TAG, "purchases: " + result.getDebugMessage());
                finish(restoring ? "failed" : "unavailable");
                return;
            }
            take(purchases);
            if (restoring) {
                finish(owned ? "restored" : "none");
            } else {
                finish("ready");
            }
        }));
    }

    /** Notes whether +purchases+ include ours, and acknowledges it. */
    private void take(List<Purchase> purchases) {
        for (Purchase purchase : purchases) {
            if (!purchase.getProducts().contains(productId) || purchase.getPurchaseState() != Purchase.PurchaseState.PURCHASED) {
                continue;
            }
            owned = true;
            receipt = "play:" + Base64.encodeToString(purchase.getOriginalJson().getBytes(StandardCharsets.UTF_8), Base64.NO_WRAP)
                + ":" + purchase.getSignature().replace("\n", "");
            if (!purchase.isAcknowledged()) {
                AcknowledgePurchaseParams params = AcknowledgePurchaseParams.newBuilder()
                    .setPurchaseToken(purchase.getPurchaseToken())
                    .build();
                client.acknowledgePurchase(params, result -> Log.i(TAG, "acknowledged: " + result.getResponseCode()));
            }
        }
    }

    private void finish(String newState) {
        state = newState;
        write();
    }

    private void write() {
        String clean = price.replace('\n', ' ');
        String text = "answer=" + number + "\nowned=" + (owned ? 1 : 0) + "\nstate=" + state + "\nprice=" + clean + "\n"
            + (owned ? "receipt=" + receipt + "\n" : "");
        try {
            File directory = file.getAbsoluteFile().getParentFile();
            directory.mkdirs();
            File temporary = new File(directory, file.getName() + ".tmp");
            Files.write(temporary.toPath(), text.getBytes(StandardCharsets.UTF_8));
            Files.move(temporary.toPath(), file.toPath(), StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE);
        } catch (IOException e) {
            Log.e(TAG, "could not write the store's answer", e);
        }
    }
}
