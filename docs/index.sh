function extract_style() {
  cat "index.html" | xmllint --html --xpath '//style' - | sed -E 's/^<\/?style>$//g'
}

function extract_content() {
  local _filestem="${1}"
  cat "${_filestem}.html" | xmllint --html --xpath '//div[@id="content"]' -
}

function render_button() {
  local _filestem="${1}"
  echo '<button class="tablinks" onclick="openCity(event, '"'${_filestem}'"')" id="defaultOpen">'"${_filestem^}"'</button>'
}

function render_content() {
  local _filestem="${1}"
  echo '<div id="'${_filestem^}'" class="tabcontent">'
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
  echo '<div class="tab">'
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
  extract_style
  end_header
  local i
  for i in "${_filestems[@]}"; do
    render_button "${i}"
  done

  for i in "${_filestems[@]}"; do
    render_content "${i}"
  done

  end_body
  print_footer
}

render features design