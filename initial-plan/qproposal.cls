% qproposal.cls -- Qyber project plan / proposal class (article-style)
%
% Engines: pdfLaTeX, XeLaTeX, LuaLaTeX.
% Layout: A4, 12pt, 3cm margins; single line spacing by default; raggedright (default)
%   or justified; section-based running heads (no chapters).
% Style and typography are chosen to match qdissertation as closely as possible,
% but this class is self-contained and based on the article class.
%
% SPDX-FileCopyrightText: 2026 Frank Langbein <frank@langbein.org>
% SPDX-License-Identifier: LPPL-1.3c
% This file may be distributed and/or modified under the terms of the
% LaTeX Project Public License (LPPL), version 1.3c.
% The latest version of this license is at https://www.latex-project.org/lppl/
% This work has the LPPL maintenance status `maintained'.
% The Current Maintainer of this work is Frank Langbein <frank@langbein.org>.
% This work consists of this file and the template files in the same distribution.
%
% User commands (set in preamble):
%   \title{Initial Plan: <Project Title>}
%   \author{<Author Name>}
%   \supervisor{<Supervisor Name>}       (optional)
%   \date{<Date>}                        (optional, defaults to \today)
%   \license{SPDX-ID}                    (optional; enables short License section in \bib)
%   \copyrightholder{}, \licenseyear{}   (optional; used in License text)
%
% In document:
%   \maketitle
%   \begin{abstract}...\end{abstract}    (optional)
%   \bib{basename}                       for bibliography and optional License section.
%

\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{qproposal}[2026/03/02 Qyber project plan/proposal class]

\makeatletter

% ------------------------------------------------------------------------------
% Class options (mirroring qdissertation where meaningful)
% ------------------------------------------------------------------------------

% Alignment: raggedright (default) or justified
\newif\ifqproposal@justify
\qproposal@justifyfalse
\DeclareOption{raggedright}{\qproposal@justifyfalse}
\DeclareOption{justified}{\qproposal@justifytrue}

% Font family: sans (default), serif, hacker (monospace-style)
\newif\ifqproposal@font@sans
\newif\ifqproposal@font@serif
\newif\ifqproposal@font@hacker
\qproposal@font@sanstrue
\qproposal@font@seriffalse
\qproposal@font@hackerfalse
\DeclareOption{sans}{%
  \qproposal@font@sanstrue
  \qproposal@font@seriffalse
  \qproposal@font@hackerfalse
}
\DeclareOption{serif}{%
  \qproposal@font@sansfalse
  \qproposal@font@seriftrue
  \qproposal@font@hackerfalse
}
\DeclareOption{hacker}{%
  \qproposal@font@sansfalse
  \qproposal@font@seriffalse
  \qproposal@font@hackertrue
}

% Obfuscation (LuaLaTeX only; same behaviour as qdissertation, but local to this class)
\newif\ifqproposal@noobfuscate
\qproposal@noobfuscatetrue
\DeclareOption{noobfuscate}{\qproposal@noobfuscatetrue}
\DeclareOption{obfuscate}{\qproposal@noobfuscatefalse}

% Citation style: numeric (default) or harvard (author-year)
\newif\ifqproposal@cite@harvard
\qproposal@cite@harvardfalse
\DeclareOption{harvard}{\qproposal@cite@harvardtrue}
\DeclareOption{numeric}{\qproposal@cite@harvardfalse}

% Single- vs double-sided layout (passed to base article class)
\newif\ifqproposal@twoside
\qproposal@twosidefalse
\DeclareOption{twoside}{%
  \PassOptionsToClass{twoside}{article}%
  \qproposal@twosidetrue
}
\DeclareOption{oneside}{%
  \PassOptionsToClass{oneside}{article}%
  \qproposal@twosidefalse
}

% Line spacing: single (default), onehalfspacing, or linespread115 / linespread12
\newif\ifqproposal@onehalfspacing
\newif\ifqproposal@linespread
\qproposal@onehalfspacingfalse
\qproposal@linespreadfalse
\DeclareOption{single}{%
  \qproposal@onehalfspacingfalse
  \qproposal@linespreadfalse
}
\DeclareOption{onehalfspacing}{\qproposal@onehalfspacingtrue\qproposal@linespreadfalse}
\DeclareOption{linespread115}{\qproposal@linespreadtrue\def\qproposal@linespreadval{1.15}}
\DeclareOption{linespread12}{\qproposal@linespreadtrue\def\qproposal@linespreadval{1.2}}

% Paragraph style: parskip (default) or parindent
\newif\ifqproposal@parindent
\qproposal@parindentfalse
\DeclareOption{parskip}{\qproposal@parindentfalse}
\DeclareOption{parindent}{\qproposal@parindenttrue}

% fullwidth = enable fullwidth environment and fullwidthfigure/table
\newif\ifqproposal@fullwidth
\qproposal@fullwidthfalse
\DeclareOption{fullwidth}{\qproposal@fullwidthtrue}

% italic = section/subsection headings in italic (default is bold/roman)
\newif\ifqproposal@italic
\qproposal@italicfalse
\DeclareOption{italic}{\qproposal@italictrue}

% Any other options are passed to the base article class
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{article}}

\ProcessOptions\relax
\LoadClass[12pt,a4paper]{article}

% ------------------------------------------------------------------------------
% Packages for layout and behaviour (mirroring qdissertation, locally)
% ------------------------------------------------------------------------------

\RequirePackage{iftex}
\ifPDFTeX
  \RequirePackage[T1]{fontenc}%
  \RequirePackage[utf8]{inputenc}%
  \RequirePackage{lmodern}%
\fi

\RequirePackage{fix-cm}% Allow CM to scale to arbitrary sizes if used
\RequirePackage[a4paper,margin=3.0cm]{geometry}% Same margins as qdissertation

% Float placement: relaxed so floats sit close to references
\renewcommand{\topfraction}{0.9}
\renewcommand{\bottomfraction}{0.7}
\renewcommand{\textfraction}{0.05}
\renewcommand{\floatpagefraction}{0.8}
\setcounter{topnumber}{4}
\setcounter{bottomnumber}{3}
\setcounter{totalnumber}{6}

\RequirePackage{graphicx}
\RequirePackage{amsmath,amsfonts,amssymb}
\RequirePackage[dvipsnames,svgnames]{xcolor}
\RequirePackage[tracking]{microtype}
\RequirePackage{setspace}
\ifqproposal@justify
  \RequirePackage{ragged2e}% justified body; still available for local \RaggedRight
\else
  \RequirePackage[document]{ragged2e}% ragged-right paragraphs
\fi
\RequirePackage{etoolbox}

% fullwidth content via adjustwidth if requested
\ifqproposal@fullwidth
  \IfFileExists{changepage.sty}{%
    \RequirePackage[strict]{changepage}%
  }{%
    \IfFileExists{chngpage.sty}{%
      \RequirePackage[strict]{chngpage}%
    }{%
      \PackageWarning{qproposal}{fullwidth option requires changepage or chngpage; fullwidth disabled}%
      \qproposal@fullwidthfalse
    }%
  }%
\fi

% LOF/LOT/LOA writefile patch (same idea as qdissertation, but local names)
\newwrite\tf@lof
\newwrite\tf@lot
\newwrite\tf@loa
\long\def\qproposal@writelist#1#2{%
  \@ifundefined{qproposal@opened@#1}{%
    \immediate\openout\csname tf@#1\endcsname\jobname.#1
    \expandafter\gdef\csname qproposal@opened@#1\endcsname{}%
  }{}%
  \immediate\write\csname tf@#1\endcsname{\unexpanded{#2}}%
}
\def\qproposal@write@lof#1{\qproposal@writelist{lof}{#1}}
\def\qproposal@write@lot#1{\qproposal@writelist{lot}{#1}}
\def\qproposal@write@loa#1{\qproposal@writelist{loa}{#1}}
\long\def\qproposal@writefile#1#2{%
  \edef\qproposal@write@arg{#1}%
  \ifx\qproposal@write@arg\qproposal@lofstr
    \qproposal@write@lof{#2}%
  \else
    \ifx\qproposal@write@arg\qproposal@lotstr
      \qproposal@write@lot{#2}%
    \else
      \ifx\qproposal@write@arg\qproposal@loastr
        \qproposal@write@loa{#2}%
      \else
        \@gobbletwo{#1}{#2}%
      \fi
    \fi
  \fi
}
\def\qproposal@lofstr{lof}\def\qproposal@lotstr{lot}\def\qproposal@loastr{loa}
\patchcmd{\document}{\let\@writefile\@gobbletwo}{\let\@writefile\qproposal@writefile}{}{}

% Citations: natbib with options matching class (harvard or numeric)
\ifqproposal@cite@harvard
  \RequirePackage[authoryear,round,sort&compress,longnamesfirst]{natbib}%
  \bibpunct{(}{)}{;}{a}{,}{,}%
\else
  \RequirePackage[numbers,sort&compress,square]{natbib}%
  \bibpunct{[}{]}{,}{n}{,}{,}%
\fi
\RequirePackage{xurl}
\RequirePackage{hyperref}
\ifPDFTeX
  \RequirePackage[hyphenbreaks]{breakurl}%
\fi

% Glossaries: acronym-only list (optional; same pattern as qdissertation)
\RequirePackage[acronym,nomain,toc]{glossaries}
\setacronymstyle{long-short}
\makeglossaries
\newif\ifqproposal@hasacronyms
\qproposal@hasacronymsfalse
\pretocmd{\newacronym}{\global\qproposal@hasacronymstrue}{}{}
\newcommand{\qproposalacronymfile}{acronyms.tex}
\IfFileExists{\qproposalacronymfile}{\input{\qproposalacronymfile}}{}
\AtBeginDocument{\glsaddall}

% Redirect bare \cite to \citep and emit a warning
\renewcommand{\cite}{%
  \PackageWarning{qproposal}{Use \string\citep\space or \string\citet\space instead of \string\cite}%
  \citep
}

\RequirePackage[font=small]{caption}
\setlength{\abovecaptionskip}{6pt}%
\setlength{\belowcaptionskip}{6pt}%
\ifqproposal@italic
  \captionsetup{labelfont=it,textfont=it}%
\fi
\RequirePackage{textcomp}

% Epigraph (copied from qdissertation/qtex for completeness)
\newcommand{\epigraph}[2]{%
  \par\vspace{1.5\baselineskip}%
  \begin{flushright}%
  \small #1\par
  \vspace{0.5ex}%
  \textit{#2}%
  \end{flushright}%
  \vspace{\baselineskip}%
  \par
}

% ------------------------------------------------------------------------------
% Font configuration (sans/serif/hacker, with optional Lua obfuscation)
% ------------------------------------------------------------------------------

\ifPDFTeX
  \ifqproposal@font@sans
    \RequirePackage[default]{sourcesanspro}%
    \RequirePackage{newtxmath}%
    \renewcommand{\familydefault}{\sfdefault}%
  \fi
  \ifqproposal@font@serif
    \RequirePackage[default]{sourceserifpro}%
    \RequirePackage{newtxmath}%
  \fi
  \ifqproposal@font@hacker
    \RequirePackage{inconsolata}%
    \RequirePackage{newtxmath}%
    \renewcommand{\familydefault}{\ttdefault}%
  \fi
\else
  \RequirePackage{fontspec}
  \defaultfontfeatures{Ligatures=TeX}
  \ifluatex
    \ifqproposal@noobfuscate \else
      \IfFileExists{fonts/obfuscate-perm.lua}{%
        \directlua{%
          local perm = dofile("fonts/obfuscate-perm.lua")
          local PUA = 0xE000
          luatexbase.add_to_callback("luaotfload.patch_font", function(tfmdata)
            if not tfmdata or not tfmdata.characters then return end
            if not tfmdata.characters[PUA] then return end
            if tfmdata.characters[0x41] then return end
            tfmdata.embedding = "full"
            tfmdata.qproposal_obfuscated = true
            for c = 0, 255 do
              local src = PUA + perm[c]
              if tfmdata.characters[src] then
                tfmdata.characters[c] = tfmdata.characters[src]
              end
            end
            for c = 0, 255 do
              local slot = PUA + perm[c]
              if tfmdata.characters[slot] then
                tfmdata.characters[slot].unicode = slot
                tfmdata.characters[slot].tounicode = slot
              end
            end
          end, "qproposal_obfuscate_full_embed")
        }%
        \AtBeginDocument{%
          \directlua{%
            local perm = dofile("fonts/obfuscate-perm.lua")
            local PUA = 0xE000
            local hlist_id = node.id("hlist")
            local vlist_id = node.id("vlist")
            local function obfuscate_glyphs(head)
              for n in node.traverse(head) do
                if n.id == node.id("glyph") then
                  local tfm = fonts.hashes.identifiers[n.font]
                  if tfm and tfm.qproposal_obfuscated and n.char >= 0 and n.char <= 255 and perm[n.char] then
                    n.char = PUA + perm[n.char]
                  end
                elseif (n.id == hlist_id or n.id == vlist_id) and n.head then
                  obfuscate_glyphs(n.head)
                end
              end
              return head
            end
            luatexbase.add_to_callback("pre_linebreak_filter", obfuscate_glyphs, "qproposal_obfuscate")
            luatexbase.add_to_callback("pre_output_filter", obfuscate_glyphs, "qproposal_obfuscate")
          }%
        }%
      }{%
        \PackageError{qproposal}{%
          Obfuscation requires fonts/obfuscate-perm.lua.\MessageBreak
          Generate it with the build script (see README).%
        }{Then re-run LaTeX.}%
      }%
    \fi
  \else
    \ifqproposal@noobfuscate \else
      \PackageWarningNoLine{qproposal}{Obfuscation is LuaLaTeX-only; using normal fonts}%
    \fi
  \fi
  \ifqproposal@font@sans
    \ifluatex \ifqproposal@noobfuscate \else
      \IfFileExists{fonts/sans-obfuscated.otf}{%
        \def\qproposal@obf@opts{Path=fonts/,Extension=.otf}%
        \IfFileExists{fonts/sans-obfuscated-Bold.otf}{\g@addto@macro\qproposal@obf@opts{,BoldFont=sans-obfuscated-Bold}}{}%
        \IfFileExists{fonts/sans-obfuscated-Italic.otf}{\g@addto@macro\qproposal@obf@opts{,ItalicFont=sans-obfuscated-Italic}}{}%
        \IfFileExists{fonts/sans-obfuscated-BoldItalic.otf}{\g@addto@macro\qproposal@obf@opts{,BoldItalicFont=sans-obfuscated-BoldItalic}}{}%
        \IfFileExists{fonts/sans-obfuscated-SmallCaps.otf}{\g@addto@macro\qproposal@obf@opts{,SmallCapsFont=sans-obfuscated-SmallCaps}}{}%
        \IfFileExists{fonts/sans-obfuscated-Slanted.otf}{\g@addto@macro\qproposal@obf@opts{,SlantedFont=sans-obfuscated-Slanted}}{}%
        \setmainfont{sans-obfuscated}[\qproposal@obf@opts]%
        \setsansfont{sans-obfuscated}[\qproposal@obf@opts]%
        \setmonofont{sans-obfuscated}[\qproposal@obf@opts]%
        \renewcommand{\labelitemi}{\normalfont\char"B7}%
        \renewcommand{\labelitemii}{\normalfont\char"B7}%
        \renewcommand{\labelitemiii}{\normalfont\char"B7}%
        \renewcommand{\labelitemiv}{\normalfont\char"B7}%
      }{%
        \PackageError{qproposal}{%
          Obfuscation requires fonts/sans-obfuscated.otf.\MessageBreak
          Generate it with the build script (see README).%
        }{Then re-run LaTeX.}%
      }%
    \fi \fi
    \ifqproposal@noobfuscate
      \IfFontExistsTF{Source Sans Pro}{%
        \setmainfont{Source Sans Pro}%
        \setsansfont{Source Sans Pro}%
        \IfFontExistsTF{Source Code Pro}{%
          \setmonofont{Source Code Pro}[Scale=MatchLowercase]%
        }{%
          \setmonofont{TeX Gyre Cursor}[Scale=MatchLowercase]%
        }%
      }{%
        \PackageWarningNoLine{qproposal}{Source Pro not found; using TeX Gyre Heros/Cursor}%
        \setmainfont{TeX Gyre Heros}%
        \setsansfont{TeX Gyre Heros}%
        \setmonofont{TeX Gyre Cursor}[Scale=MatchLowercase]%
      }%
    \else
      \ifluatex \else
        \IfFontExistsTF{Source Sans Pro}{%
          \setmainfont{Source Sans Pro}%
          \setsansfont{Source Sans Pro}%
          \IfFontExistsTF{Source Code Pro}{%
            \setmonofont{Source Code Pro}[Scale=MatchLowercase]%
          }{%
            \setmonofont{TeX Gyre Cursor}[Scale=MatchLowercase]%
          }%
        }{%
          \PackageWarningNoLine{qproposal}{Source Pro not found; using TeX Gyre Heros/Cursor}%
          \setmainfont{TeX Gyre Heros}%
          \setsansfont{TeX Gyre Heros}%
          \setmonofont{TeX Gyre Cursor}[Scale=MatchLowercase]%
        }%
      \fi
    \fi
  \fi
  \ifqproposal@font@serif
    \ifluatex \ifqproposal@noobfuscate \else
      \IfFileExists{fonts/serif-obfuscated.otf}{%
        \def\qproposal@obf@opts{Path=fonts/,Extension=.otf}%
        \IfFileExists{fonts/serif-obfuscated-Bold.otf}{\g@addto@macro\qproposal@obf@opts{,BoldFont=serif-obfuscated-Bold}}{}%
        \IfFileExists{fonts/serif-obfuscated-Italic.otf}{\g@addto@macro\qproposal@obf@opts{,ItalicFont=serif-obfuscated-Italic}}{}%
        \IfFileExists{fonts/serif-obfuscated-BoldItalic.otf}{\g@addto@macro\qproposal@obf@opts{,BoldItalicFont=serif-obfuscated-BoldItalic}}{}%
        \IfFileExists{fonts/serif-obfuscated-SmallCaps.otf}{\g@addto@macro\qproposal@obf@opts{,SmallCapsFont=serif-obfuscated-SmallCaps}}{}%
        \IfFileExists{fonts/serif-obfuscated-Slanted.otf}{\g@addto@macro\qproposal@obf@opts{,SlantedFont=serif-obfuscated-Slanted}}{}%
        \setmainfont{serif-obfuscated}[\qproposal@obf@opts]%
        \setsansfont{serif-obfuscated}[\qproposal@obf@opts]%
        \setmonofont{serif-obfuscated}[\qproposal@obf@opts]%
        \renewcommand{\labelitemi}{\normalfont\char"B7}%
        \renewcommand{\labelitemii}{\normalfont\char"B7}%
        \renewcommand{\labelitemiii}{\normalfont\char"B7}%
        \renewcommand{\labelitemiv}{\normalfont\char"B7}%
      }{%
        \PackageError{qproposal}{%
          Obfuscation requires fonts/serif-obfuscated.otf.\MessageBreak
          Generate it with the build script (see README).%
        }{Then re-run LaTeX.}%
      }%
    \fi \fi
    \ifqproposal@noobfuscate
      \IfFontExistsTF{Source Serif Pro}{%
        \setmainfont{Source Serif Pro}%
        \setsansfont{Source Sans Pro}[Scale=MatchLowercase]%
        \IfFontExistsTF{Source Code Pro}{%
          \setmonofont{Source Code Pro}[Scale=MatchLowercase]%
        }{%
          \setmonofont{TeX Gyre Cursor}[Scale=MatchLowercase]%
        }%
      }{%
        \PackageWarningNoLine{qproposal}{Source Pro not found; using TeX Gyre Termes/Heros/Cursor}%
        \setmainfont{TeX Gyre Termes}%
        \setsansfont{TeX Gyre Heros}[Scale=MatchLowercase]%
        \setmonofont{TeX Gyre Cursor}[Scale=MatchLowercase]%
      }%
    \else
      \ifluatex \else
        \IfFontExistsTF{Source Serif Pro}{%
          \setmainfont{Source Serif Pro}%
          \setsansfont{Source Sans Pro}[Scale=MatchLowercase]%
          \IfFontExistsTF{Source Code Pro}{%
            \setmonofont{Source Code Pro}[Scale=MatchLowercase]%
          }{%
            \setmonofont{TeX Gyre Cursor}[Scale=MatchLowercase]%
          }%
        }{%
          \PackageWarningNoLine{qproposal}{Source Pro not found; using TeX Gyre Termes/Heros/Cursor}%
          \setmainfont{TeX Gyre Termes}%
          \setsansfont{TeX Gyre Heros}[Scale=MatchLowercase]%
          \setmonofont{TeX Gyre Cursor}[Scale=MatchLowercase]%
        }%
      \fi
    \fi
  \fi
  \ifqproposal@font@hacker
    \ifluatex \ifqproposal@noobfuscate \else
      \IfFileExists{fonts/hacker-obfuscated.otf}{%
        \def\qproposal@obf@opts{Path=fonts/,Extension=.otf}%
        \IfFileExists{fonts/hacker-obfuscated-Bold.otf}{\g@addto@macro\qproposal@obf@opts{,BoldFont=hacker-obfuscated-Bold}}{}%
        \IfFileExists{fonts/hacker-obfuscated-Italic.otf}{\g@addto@macro\qproposal@obf@opts{,ItalicFont=hacker-obfuscated-Italic}}{}%
        \IfFileExists{fonts/hacker-obfuscated-BoldItalic.otf}{\g@addto@macro\qproposal@obf@opts{,BoldItalicFont=hacker-obfuscated-BoldItalic}}{}%
        \IfFileExists{fonts/hacker-obfuscated-SmallCaps.otf}{\g@addto@macro\qproposal@obf@opts{,SmallCapsFont=hacker-obfuscated-SmallCaps}}{}%
        \IfFileExists{fonts/hacker-obfuscated-Slanted.otf}{\g@addto@macro\qproposal@obf@opts{,SlantedFont=hacker-obfuscated-Slanted}}{}%
        \setmainfont{hacker-obfuscated}[\qproposal@obf@opts]%
        \setsansfont{hacker-obfuscated}[\qproposal@obf@opts]%
        \setmonofont{hacker-obfuscated}[\qproposal@obf@opts]%
        \renewcommand{\labelitemi}{\normalfont\char"B7}%
        \renewcommand{\labelitemii}{\normalfont\char"B7}%
        \renewcommand{\labelitemiii}{\normalfont\char"B7}%
        \renewcommand{\labelitemiv}{\normalfont\char"B7}%
      }{%
        \PackageError{qproposal}{%
          Obfuscation requires fonts/hacker-obfuscated.otf.\MessageBreak
          Generate it with the build script (see README).%
        }{Then re-run LaTeX.}%
      }%
    \fi \fi
    \ifqproposal@noobfuscate
      \IfFontExistsTF{Inconsolata}{%
        \setmainfont{Inconsolata}%
        \setsansfont{Inconsolata}%
        \setmonofont{Inconsolata}%
      }{%
        \setmainfont{Fira Mono}%
        \setsansfont{Fira Mono}%
        \setmonofont{Fira Mono}%
      }%
    \else
      \ifluatex \else
        \PackageWarning{qproposal}{%
          Obfuscation is supported only with LuaLaTeX.\MessageBreak
          Using normal hacker font (no obfuscation).%
        }%
        \IfFontExistsTF{Inconsolata}{%
          \setmainfont{Inconsolata}%
          \setsansfont{Inconsolata}%
          \setmonofont{Inconsolata}%
        }{%
          \setmainfont{Fira Mono}%
          \setsansfont{Fira Mono}%
          \setmonofont{Fira Mono}%
        }%
      \fi
    \fi
  \fi
  \RequirePackage{unicode-math}%
  \setmathfont{Latin Modern Math}[Scale=MatchLowercase]%
\fi

% ------------------------------------------------------------------------------
% Layout defaults (spacing, paragraph style, quotes, fullwidth)
% ------------------------------------------------------------------------------

\ifqproposal@onehalfspacing
  \onehalfspacing
\else
  \ifqproposal@linespread
    \linespread{\qproposal@linespreadval}%
  \else
    \singlespacing
  \fi
\fi
\ifqproposal@justify\else \RaggedRight\fi
\emergencystretch=3em

% Tight list style
\setlength{\leftmargini}{1pc}
\setlength{\leftmarginii}{1pc}
\setlength{\leftmarginiii}{1pc}
\setlength{\leftmarginiv}{1pc}
\setlength{\leftmarginv}{1pc}
\setlength{\leftmarginvi}{1pc}
\setlength{\labelsep}{0.5pc}
\setlength{\labelwidth}{\leftmargini}
\addtolength{\labelwidth}{-\labelsep}

% Quote environments: smaller type and indents
\renewenvironment{verse}
 {\let\\\@centercr
  \list{}{\itemsep \z@
  \itemindent -1pc%
  \listparindent\itemindent
  \rightmargin \leftmargin
  \advance\leftmargin 1pc}%
  \small%
  \item\relax}
 {\endlist}
\renewenvironment{quotation}
 {\list{}{\listparindent 1pc%
  \itemindent \listparindent
  \rightmargin \leftmargin
  \parsep \z@ \@plus\p@}%
  \small%
  \item\relax\noindent\ignorespaces}
 {\endlist}
\renewenvironment{quote}
 {\list{}{\rightmargin\leftmargin}%
  \small%
  \item\relax}
 {\endlist}

% Paragraph style: parskip (default) or parindent
\ifqproposal@parindent
  \setlength{\parindent}{1em}%
  \setlength{\parskip}{0pt}%
  \setlength{\RaggedRightParindent}{1em}%
\else
  \RequirePackage{parskip}%
\fi

% fullwidth environments when option fullwidth is set
\newlength{\qproposal@fullwidth@overhang}
\setlength{\qproposal@fullwidth@overhang}{2cm}
\ifqproposal@fullwidth
  \newenvironment{fullwidth}{%
    \begin{adjustwidth}{-\qproposal@fullwidth@overhang}{-\qproposal@fullwidth@overhang}%
  }{%
    \end{adjustwidth}%
  }
  \newenvironment{fullwidthfigure}[1][htbp]{%
    \begin{figure}[#1]%
    \begin{adjustwidth}{-\qproposal@fullwidth@overhang}{-\qproposal@fullwidth@overhang}%
    \centering
  }{%
    \end{adjustwidth}%
    \end{figure}%
  }
  \newenvironment{fullwidthtable}[1][htbp]{%
    \begin{table}[#1]%
    \begin{adjustwidth}{-\qproposal@fullwidth@overhang}{-\qproposal@fullwidth@overhang}%
    \centering
  }{%
    \end{adjustwidth}%
    \end{table}%
  }
\else
  \newenvironment{fullwidth}{\begingroup}{\endgroup}
\fi

% newthought (drop-word style) matching qdissertation/qtex
\newskip\qproposal@newthoughtskip
\setlength{\qproposal@newthoughtskip}{1.0\baselineskip plus 0.5ex minus 0.2ex}
\@ifundefined{textls}{%
  \newcommand{\newthought}[1]{\par\vspace{\qproposal@newthoughtskip}\noindent\textsc{#1}}%
}{%
  \newcommand{\newthought}[1]{\par\vspace{\qproposal@newthoughtskip}\noindent\textls[50]{\scshape #1}}%
}

% Display math spacing
\setlength{\abovedisplayskip}{6pt plus 2pt minus 4pt}%
\setlength{\belowdisplayskip}{6pt plus 2pt minus 4pt}%

% Footnote rule
\renewcommand{\footnoterule}{%
  \vspace*{4pt}%
  \hrule width 0.4\columnwidth height 0.4pt
  \vspace{4pt}%
}

% ------------------------------------------------------------------------------
% Section/subsection formatting (titlesec)
% ------------------------------------------------------------------------------

\RequirePackage{titlesec}%
\ifqproposal@italic
  \titleformat{\section}[hang]{\normalfont\Large\itshape}{\thesection}{1em}{}%
  \titleformat{\subsection}[hang]{\normalfont\large\itshape}{\thesubsection}{1em}{}%
\else
  \titleformat{\section}[hang]{\normalfont\Large\bfseries}{\thesection}{1em}{}%
  \titleformat{\subsection}[hang]{\normalfont\large\bfseries}{\thesubsection}{1em}{}%
\fi
\titlespacing*{\section}{0pt}{3.5ex plus 1ex minus .2ex}{2.3ex plus .2ex}%
\titlespacing*{\subsection}{0pt}{3.25ex plus 1ex minus .2ex}{1.5ex plus .2ex}%

% First paragraph after section: no indent when parindent is enabled
\ifqproposal@parindent
  \let\qproposal@orig@afterheading\@afterheading
  \renewcommand{\@afterheading}{%
    \qproposal@orig@afterheading
    \noindent
  }
\fi

% ------------------------------------------------------------------------------
% Page style (section-based running heads; no chapter bar)
% ------------------------------------------------------------------------------

\RequirePackage{fancyhdr}
\newlength{\qproposal@headruleheight}
\setlength{\qproposal@headruleheight}{0.4pt}
\setlength{\headheight}{14.5pt}

\fancypagestyle{plain}{%
  \fancyhf{}%
  \ifqproposal@twoside
    \fancyhead[LE,RO]{\thepage}%
    \fancyhead[LO,RE]{\textls[50]{\scshape\leftmark}}%
  \else
    \fancyhead[L]{\textls[50]{\scshape\leftmark}}%
    \fancyhead[R]{\thepage}%
  \fi
  \renewcommand{\headrulewidth}{\qproposal@headruleheight}%
}
\fancypagestyle{empty}{%
  \fancyhf{}%
  \renewcommand{\headrulewidth}{0pt}%
  \renewcommand{\footrulewidth}{0pt}%
}

\pagestyle{plain}
\renewcommand{\sectionmark}[1]{%
  \markboth{\ifnum\c@secnumdepth>\z@\thesection\ \fi#1}{}%
}
\renewcommand{\subsectionmark}[1]{%
  \markright{\ifnum\c@secnumdepth>\m@ne\thesubsection\ \fi#1}%
}

% Ensure LOF/LOT/LOA are closed after .aux is read so lists work if used
\AtBeginDocument{%
  \@ifundefined{qproposal@opened@lof}{}{\immediate\closeout\tf@lof}%
  \@ifundefined{qproposal@opened@lot}{}{\immediate\closeout\tf@lot}%
  \@ifundefined{qproposal@opened@loa}{}{\immediate\closeout\tf@loa}%
}

% ------------------------------------------------------------------------------
% Metadata and license (minimal, self-contained)
% ------------------------------------------------------------------------------

\newcommand{\qproposal@title}{}
\newcommand{\qproposal@author}{}
\newcommand{\qproposal@supervisor}{}
\newcommand{\qproposal@date}{\today}

\renewcommand{\title}[1]{\gdef\qproposal@title{#1}}
\renewcommand{\author}[1]{\gdef\qproposal@author{#1}}
\newcommand{\supervisor}[1]{\gdef\qproposal@supervisor{#1}}
\renewcommand{\date}[1]{\gdef\qproposal@date{#1}}

% Keywords (for abstract)
\gdef\qproposal@keywords{}%
\newif\ifqproposal@haskeywords
\qproposal@haskeywordsfalse
\newcommand{\keywords}[1]{%
  \gdef\qproposal@keywords{#1}%
  \ifstrempty{#1}{}{%
    \qproposal@haskeywordstrue
  }%
}

% License metadata (SPDX)
\newif\ifqproposal@license
\qproposal@licensefalse
\gdef\qproposal@licenseid{}%
\gdef\qproposal@copyrightholder{}%
\gdef\qproposal@licenseyear{}%
\newcommand{\license}[1]{%
  \qproposal@licensetrue
  \gdef\qproposal@licenseid{#1}%
}
\newcommand{\copyrightholder}[1]{\gdef\qproposal@copyrightholder{#1}}
\newcommand{\licenseyear}[1]{\gdef\qproposal@licenseyear{#1}}

% SPDX ID -> {display name, URL}
\def\qproposal@setlicfrompair#1{\expandafter\qproposal@setlicfrompair@aux#1}
\def\qproposal@setlicfrompair@aux#1#2{\gdef\qproposal@lic@name{#1}\gdef\qproposal@lic@url{#2}}
\expandafter\def\csname qproposal@lic@MIT\endcsname{{MIT License}{https://spdx.org/licenses/MIT.html}}
\expandafter\def\csname qproposal@lic@Apache-2.0\endcsname{{Apache License 2.0}{https://www.apache.org/licenses/LICENSE-2.0}}
\expandafter\def\csname qproposal@lic@GPL-3.0-only\endcsname{{GNU GPL License v3.0 only}{https://spdx.org/licenses/GPL-3.0-only.html}}
\expandafter\def\csname qproposal@lic@GPL-3.0-or-later\endcsname{{GNU GPL License v3.0 or later}{https://spdx.org/licenses/GPL-3.0-or-later.html}}
\expandafter\def\csname qproposal@lic@AGPL-3.0-only\endcsname{{GNU AGPL License v3.0 only}{https://spdx.org/licenses/AGPL-3.0-only.html}}
\expandafter\def\csname qproposal@lic@AGPL-3.0-or-later\endcsname{{GNU AGPL License v3.0 or later}{https://spdx.org/licenses/AGPL-3.0-or-later.html}}
\expandafter\def\csname qproposal@lic@GFDL-1.3\endcsname{{GNU Free Documentation License 1.3}{https://www.gnu.org/licenses/fdl-1.3.html}}
\expandafter\def\csname qproposal@lic@CC-BY-4.0\endcsname{{Creative Commons Attribution License 4.0}{https://creativecommons.org/licenses/by/4.0/legalcode}}
\expandafter\def\csname qproposal@lic@CC-BY-SA-4.0\endcsname{{Creative Commons Attribution-ShareAlike License 4.0}{https://creativecommons.org/licenses/by-sa/4.0/legalcode}}
\expandafter\def\csname qproposal@lic@CC-BY-NC-4.0\endcsname{{Creative Commons Attribution-NonCommercial License 4.0}{https://creativecommons.org/licenses/by-nc/4.0/legalcode}}
\expandafter\def\csname qproposal@lic@CC-BY-NC-SA-4.0\endcsname{{Creative Commons Attribution-NonCommercial-ShareAlike License 4.0}{https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode}}
\expandafter\def\csname qproposal@lic@CC-BY-NC-ND-4.0\endcsname{{Creative Commons Attribution-NonCommercial-NoDerivatives License 4.0}{https://creativecommons.org/licenses/by-nc-nd/4.0/legalcode}}
\expandafter\def\csname qproposal@lic@CC-BY-ND-4.0\endcsname{{Creative Commons Attribution-NoDerivatives License 4.0}{https://creativecommons.org/licenses/by-nd/4.0/legalcode}}
\expandafter\def\csname qproposal@lic@CC0-1.0\endcsname{{CC0 1.0 Universal}{https://creativecommons.org/publicdomain/zero/1.0/legalcode}}
\expandafter\def\csname qproposal@lic@BSD-2-Clause\endcsname{{BSD 2-Clause ``Simplified'' License}{https://spdx.org/licenses/BSD-2-Clause.html}}
\expandafter\def\csname qproposal@lic@BSD-3-Clause\endcsname{{BSD 3-Clause ``New'' or ``Revised'' License}{https://spdx.org/licenses/BSD-3-Clause.html}}
\expandafter\def\csname qproposal@lic@LPPL-1.3c\endcsname{{LaTeX Project Public License 1.3c}{https://www.latex-project.org/lppl/lppl-1-3c.html}}

\newcommand{\qproposal@resolvelicense}{%
  \edef\qproposal@lic@curid{\qproposal@licenseid}%
  \edef\qproposal@lic@cstest{qproposal@lic@\qproposal@lic@curid}%
  \expandafter\@ifundefined\expandafter{\qproposal@lic@cstest}{%
    \gdef\qproposal@lic@name{SPDX: \qproposal@licenseid}%
    \gdef\qproposal@lic@url{https://spdx.org/licenses/\qproposal@licenseid.html}%
  }{%
    \expandafter\qproposal@setlicfrompair\csname qproposal@lic@\qproposal@lic@curid\endcsname
  }%
}

% Ensure footnotes/captions stay at least 11pt (\small)
\AtBeginDocument{%
  \renewcommand{\footnotesize}{\small}%
}

% microtype and hyperref tuning
\microtypesetup{final,protrusion=true,nopatch=footnote}%
\ifXeTeX\else \microtypesetup{expansion=true}\fi

\hypersetup{%
  unicode=true,%
  breaklinks=true,%
  colorlinks=true,%
  linkcolor=DarkBlue,%
  citecolor=DarkGreen,%
  urlcolor=DarkGreen,%
  filecolor=DarkBlue,%
  menucolor=DarkBlue%
}
\let\qproposal@orig@href\href
\renewcommand{\href}[2]{%
  \qproposal@orig@href{#1}{%
    {\color{DarkBlue}#2}%
  }%
}
\def\UrlFont{\ttfamily\color{DarkGreen}}%

% ------------------------------------------------------------------------------
% Abstract environment (article-style, with rules and optional keywords)
% ------------------------------------------------------------------------------

\renewenvironment{abstract}{%
  \par\vspace*{-\parskip}\vspace*{-\baselineskip}\noindent%
  \small
  \quotation
  \noindent\rule{\linewidth}{0.4pt}\par\vspace{0.1ex}\noindent%
}{%
  \ifqproposal@haskeywords
    \par\vspace{0.25ex}\noindent\textbf{Keywords:}\ \qproposal@keywords%
  \fi
  \par\vspace*{-\baselineskip}\vspace{1ex}%
  \noindent\rule{\linewidth}{0.4pt}%
  \endquotation
}

% ------------------------------------------------------------------------------
% Maketitle (article-style, with optional Supervisor line)
% ------------------------------------------------------------------------------

\renewcommand{\maketitle}{%
  \par
  \begingroup
    \if@twocolumn
      \ifnum \col@number=\@ne
        \@maketitle
      \else
        \twocolumn[\@maketitle]%
      \fi
    \else
      \global\@topnum\z@
      \@maketitle
    \fi
    \thispagestyle{empty}%
  \endgroup
  \setcounter{footnote}{0}%
  \let\thanks\relax
  \let\maketitle\relax
  \let\@maketitle\relax
}

\def\@maketitle{%
  \begin{center}%
    {\LARGE\bfseries \qproposal@title\par}%
    \vspace{0.5ex}%
    {\large
      \lineskip .5em
      \qproposal@author\par
    }%
    \ifstrempty{\qproposal@supervisor}{}{%
      \vspace{0.5ex}%
      {\normalsize Supervisor: \qproposal@supervisor\par}%
    }%
    \vspace{0.5ex}%
    {\normalsize \qproposal@date\par}%
    \vspace{0.5ex}%
  \end{center}%
}

% ------------------------------------------------------------------------------
% Bibliography helper: \bib{basename}
% ------------------------------------------------------------------------------

\renewcommand{\bibname}{References}

\newcommand{\bib}[1]{%
  \ifqproposal@cite@harvard
    \bibliographystyle{agsm}%
  \else
    \bibliographystyle{plainnat}%
  \fi
  \ifqproposal@license
    \qproposal@resolvelicense
    \section*{License}\label{sec:license}{\small%
    Copyright\ \textcopyright\ \ifstrempty{\qproposal@licenseyear}{\number\year}{\qproposal@licenseyear}\ %
    \ifstrempty{\qproposal@copyrightholder}{\qproposal@author}{\qproposal@copyrightholder}.\\
    This work is licensed under the \qproposal@lic@name.\\{\ttfamily SPDX-License-Identifier: \qproposal@licenseid}\\
    Full text: \url{\qproposal@lic@url}}\par
  \fi
  \bibliography{#1}%
}

\makeatother

