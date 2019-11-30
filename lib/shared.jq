def path2pexp(v):
  reduce .[] as $segment (""; . + ($segment | if type == "string" then ".\"" + . + "\"" else "[\(.)]" end));
