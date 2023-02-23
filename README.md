# `jq-front`: JSON with inheritance and templating

`jq-front` is a simple tool to give your JSON files a power of inheritance and templating.

## Usage

```shell script
jq-front [-h|--help] [--validation=no|strict|lenient] [--nested-templating-levels=num] [--version] [TARGET]
```

- `-h`, `--help`: Shows a help
- `--validation`: Validation mode.
`no`, `strict`, and `lenient` are available.
- `--nested-templating-levels:` Number of times templating happens in the process. The default is 5. If templating doesn’t finish within ```num``` times, an error will be reported.
- `--version`: Shows a version.
- `TARGET`: A file to be processed. If not given, `stdin` will be processed
 
### Example


Let's prepare files, `name.json` and `greeting.json`, from which you want to create a new JSON by extending them.

```shell script
$ echo '{"yourname":"Mark"}' > name.json
$ cat name.json
{"yourname":"Mark"}

$ echo '{"greeting":"Hello"}' > greeting.json
$ cat greeting.json
{"greeting":"Hello"}
```

Then create a file that extends them.

```shell script
$ echo '{
    "$extends": ["greeting.json", "name.json"],
    "sayHello": "eval:$(ref .greeting), $(ref .yourname). Toady is $(date). How are you doing?"
  }' > sayHello.json
```

Now, let's try `jq-front`.
```shell script
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
Following tools are used to develop `jq-front`.
A version for each tool used for development and testing are found in parentheses.

* `bash` (`5.0.17`)
* `jq` (`1.6`)
* `npm` (`6.14.4`)
  * `yamljs` (`0.3.0`)

Refer to the `Dockerfile` for procedure to set up development environment. 

### With Docker

Add a following entry to your `.bashrc` or a file sourced through it.

```shell script

function jq-front() {
  docker run --rm -i \
    -v /:/var/lib/jf \
    -v "${HOME}/.jq-front.rc:/root/.jq-front.rc" \
    -e JF_PATH_BASE="/var/lib/jf" \
    -e JF_PATH="${JF_PATH}" \
    -e JF_DEBUG=${JF_DEBUG:-disabled} \
    -e JF_CWD="$(pwd)" \
    dakusui/jq-front:"${JF_DOCKER_TAG:-v0.54}" "${@}"
}

```

## Features

* File Level Inheritance
* Node Level Inheritance
* Templating (rendering text nodes referring to other nodes' values)
* Validation (strict and lenient validations)

## Documentation

You can find more about this product <a href="https://dakusui.github.io/jq-front/">here</a>.

## Contributing

### Step 0: Setting up your box

- Install dependencies mentioned in the Installation section.
- Install docker

### Step 1: Preparing local repository

- **Option 1**
    - Fork this repo.
    - If you have an account in <a href="https://hub.docker.com/">Docker Hub</a>, it might be a good idea to update `DOCKER_USER_NAME` in `build_info.sh` with yours to be able to publish your own image. 

- **Option 2**
    - Clone this repo to your local machine using `https://github.com/dakusui/jq-front.git`

### Step 2: Building the tool

The build procedure of this project can only work on Ubuntu currently.

`bulid.sh` is the tool with which you can generate documentation, perform tests, and package the tool as a docker image.
Every time it is invoked it prepares some resources before executing any tasks.

The tool scans the directory `res` and performs a templating on every file.
The scan happens in an alphabetical order of the names of the files.
And each templated file will be copied to a corresponding directory from the current.
That is, if you have a file `res/dir1/hello-world.txt`, it will be templated and copied to `dir1/hello-world.txt`.

In case a file's name starts with a digit(`[0-9]`) and contains an underscore(`_`), the file will be templated and copied to a file whose name doesn't have the portion.
`res/0hello_hello.txt` will be rendered to `hello.txt`.
This behaviour is useful when you want to include a content of another file, whose name comes latter in an alphabetical order than the file you are editing.

Note that dollar signs(`$`) contained by files under `res` directory need to be escaped by a backslash(`\`). 

#### Building the documentation

- Technical documents are stored under `docs` directory in `.adoc` format.
- Documentation format is `asciidoc`. 
`.html` files are generated automatically. Please don't edit them.
- Note that `README.md` is generated from `res/README.md` in resource preparation mechanism of the `build.sh`.
In case you want to update, edit `res/README.md`.

### Step 3: Hacking away

**HACK AWAY!** 🔨🔨🔨

Please do not forget adding test cases under `tests` directory.
Probably `tests/single` directory contains a first example that you can follow.

### Step 4: Testing the product

Please do

```shell script

$ ./build.sh PACKAGE

```

This will execute following tasks after resource preparation is finished.

* Build documentation. 
* Run tests.
* Create a Docker image.
* Run the same tests using the docker image.

### Step 4: Creating a pull request

- 🔃 Create a new pull request using <a href="https://github.com/dakusui/jq-front/compare/" target="_blank">`https://github.com/dakusui/jq-front/compare/`</a>.
Please do not forget running tests to ensure that auto-generated resources up-to-date.
Also please do not forget removing your custom configuration made on `build_info.sh`.


## Authors

* **Hrioshi Ukai** - *Initial work* - <a href="https://github.com/dakusui">dakusui</a>

## Support

* <a href="https://github.com/dakusui/jq-front/issues">Issues</a>
* Twitter at <a href="https://twitter.com/______HU">@______HU</a>

## License

[![License](http://img.shields.io/:license-mit-blue.svg?style=flat-square)](http://badges.mit-license.org)

- **[MIT license](http://opensource.org/licenses/mit-license.php)**
- Copyright 2019 © <a href="https://github.com/dakusui" target="_blank">Hiroshi Ukai</a>.
