#!/usr/bin/env bash
set -E -eu -o pipefail
# shopt -s inherit_errexit

function extract_style() {
  cat "all.html" | xmllint --html --xpath '//style' - | sed -E 's/^<\/?style>$//g'
}

function extract_content() {
  local _filestem="${1}"
  cat "${_filestem}.html" | xmllint --html --xpath '//div[@id="content"]' - | sed -E 's/<div id="content">/<div id="'"${_filestem}"'_content">/g'
}
function render_style() {
  extract_style
  cat << STYLE
// For tabs
body {font-family: Arial;}

/* Style the tab */
.tab {
  overflow: hidden;
  border: 1px solid #ccc;
  background-color: #f1f1f1;
}

/* Style the buttons inside the tab */
.tab button {
  background-color: inherit;
  float: left;
  border: none;
  outline: none;
  cursor: pointer;
  padding: 14px 16px;
  transition: 0.3s;
  font-size: 17px;
}

/* Change background color of buttons on hover */
.tab button:hover {
  background-color: #ddd;
}

/* Create an active/current tablink class */
.tab button.active {
  background-color: #ccc;
}

/* Style the tab content */
.tabcontent {
  display: none;
  padding: 6px 12px;
  border: 1px solid #ccc;
  border-top: none;
}
STYLE
}
function render_button() {
  local _filestem="${1}"
  echo '<button class="tablinks" onclick="openCity(event, '"'${_filestem}'"')">'"${_filestem}"'</button>'
}

function render_content() {
  local _filestem="${1}"
  echo '<div id="'${_filestem}'" class="tabcontent">'
  extract_content "${_filestem}"
  echo '</div>'
}

function begin_header() {
  cat <<BEGINHEADER
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta name="generator" content="Asciidoctor 2.0.10">
<title>jq-front: JSON with inheritance and templating</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css?family=Open+Sans:300,300italic,400,400italic,600,600italic%7CNoto+Serif:400,400italic,700,700italic%7CDroid+Sans+Mono:400,700">
<style>
BEGINHEADER
}

function end_header() {
  echo '</style>'
  echo '</head>'
}

function begin_body() {
  echo '<body>'
}

function end_body() {
  cat <<FOOTER
<script>
function openCity(evt, cityName) {
  var i, tabcontent, tablinks;
  tabcontent = document.getElementsByClassName("tabcontent");
  for (i = 0; i < tabcontent.length; i++) {
    tabcontent[i].style.display = "none";
  }
  tablinks = document.getElementsByClassName("tablinks");
  for (i = 0; i < tablinks.length; i++) {
    tablinks[i].className = tablinks[i].className.replace(" active", "");
  }
  document.getElementById(cityName).style.display = "block";
  evt.currentTarget.className += " active";
}

// Get the element with id="defaultOpen" and click on it
document.getElementById("defaultOpen").click();

</script>
</body>
FOOTER
}

function print_footer() {
  echo '</html>'
}

function render() {
  local _filestems=("$@")
  begin_header
  render_style
  end_header
  begin_body

  echo '<div class="tab">'
  local i
  for i in "${_filestems[@]}"; do
    render_button "${i}"
  done
  echo '</div>'

  for i in "${_filestems[@]}"; do
    render_content "${i}"
  done
  end_body
  print_footer
}

function main() {
  local _targets
  _targets=$(ls *.adoc | sed -E 's/\.adoc$//' | grep -v all| sort)
  render ${_targets[@]}
}

cd "$(dirname ${0})"
main