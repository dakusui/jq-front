# `jq-front`: JSON with inheritance and templating

`jq-front` is a simple tool to give your JSON files a power of inheritance and templating.

## Example

## Installation

### Ubuntu

Place the file `jq-front`, directory `lib`, and directory `schema` in a directory on your `PATH`.
Followings will be required by `jq-front`

* `jq`
* `bash`
* `npm`
  * `ajv-cli`

### With Docker

Add a following entry to your `.bashrc` or a file sourced through it.

```bash

function docker-jq-front() {
  local _target="${1}"
  docker run --rm \
    -v /:/var/lib/jf \
    -e JF_PATH_BASE="/var/lib/jf" \
    -e JF_PATH="${JF_PATH}" \
    -e JF_DEBUG=${JF_DEBUG:-disabled} \
    -e JF_CWD="$(pwd)" \
    dakusui/jf:"${JF_DOCKER_TAG:-v0.2}" "${@}"
}

```

## Features

(t.b.d.)

## Documentation

You can find more about this product <a href="./docs/index.html">here</a>.

## Contributing

(t.b.d.)

## Authors

* **Hrioshi Ukai** - *Initial work* - <a href="https://github.com/dakusui">dakusui</a>

## Support

* <a href="https://github.com/dakusui/jq-front/issues">Issues</a>
* Twitter at <a href="http://twitter.com/\______HU">@\______HU</a>

## License

[![License](http://img.shields.io/:license-mit-blue.svg?style=flat-square)](http://badges.mit-license.org)

- **[MIT license](http://opensource.org/licenses/mit-license.php)**
- Copyright 2015 © <a href="http://fvcproductions.com" target="_blank">FVCproductions</a>.
