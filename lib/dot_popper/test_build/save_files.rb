# frozen_string_literal: true

module DotPopper
  module Privacy
    # The test build's own save files, in their place among the asides,
    # before the developer's.
    SAVE_FILES.insert(SAVE_FILES.index { it.aside&.kind == :developer_only } || SAVE_FILES.size,
      KeptFile.new(name: "fake_setdef.txt", aside: Aside.new(kind: :test_only, reason: "Used only in test builds, as a stand-in for setdef's server."), holds: "a pretend server's record of license keys, in test builds only"),
      KeptFile.new(name: "fake_store.txt", aside: Aside.new(kind: :test_only, reason: "Used only in test builds, never with a real purchase."), holds: "a pretend purchase's receipt, signed by a test key, in test builds only"))
  end
end
