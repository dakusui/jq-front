SimpleCov.add_filter '.git'
SimpleCov.add_group 'Product Scripts', '(lib/.*\.sh$|jq-front)'
SimpleCov.add_group 'Build Scripts', 'build.*.sh|tests/.*\.sh'

