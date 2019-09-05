# `jq-front`: JSON with inheritance and templating

`jq-front` is a simple tool to give your JSON files a power of inheritance and templating.

## Example


Let's prepare files, `name.json` and `greeting.json`, from which you want to create a new JSON by extending them.

```sh
$ echo '{"yourname":"Mark"}' > name.json
$ cat name.json
{"yourname":"Mark"}

$ echo '{"greeting":"Hello"}' > greeting.json
$ cat greeting.json
{"greeting":"Hello"}
```

Then create a file that extends them.

```sh
$ echo '{
    "$extends": ["greeting.json", "name.json"],
    "sayHello": "$(ref .greeting), $(ref .yourname). Toady is $(date). How are you doing?"
  }' > sayHello.json
```

Now, let's try `jq-front`.
```sh
$ jq-front sayHello.json
{
  "yourname": "Mark",
  "greeting": "Hello",
  "sayHello": "Hello, Mark. Toady is Fri Aug 30 22:04:40 UTC 2019. How are you doing?"
}
$
```
Doesn't it seem useful? Have fun!

## Installation

### Ubuntu
Place the file `jq-front`, `lib`, and `schema` somewhere on your `PATH`.
Followings will be required by `jq-front`

* `jq`
* `bash`
* `npm`
  * `ajv-cli`

### With Docker

Add a following entry to your `.bashrc` or a file sourced through it.

```bash

$(cat jq-front_aliases)

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