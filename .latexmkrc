# Force this project to build with LuaLaTeX, even when an editor invokes
# `latexmk -pdf` (which normally defaults to pdfLaTeX).
$pdf_mode = 1;
$pdflatex = 'lualatex -interaction=nonstopmode -file-line-error %O %S';
$lualatex = 'lualatex -interaction=nonstopmode -file-line-error %O %S';

# Build glossaries/acronyms when needed.
add_cus_dep('acn', 'acr', 0, 'makeglossaries');
sub makeglossaries {
  my ($base) = @_;
  return system "makeglossaries \"$base\"";
}
