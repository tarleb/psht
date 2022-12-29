---
title: PShT
author: Albert Krewinkel
---

# Introduction

PShT is the tool for

**P**resentations in **Sh**ell and **T**erminal.

It allows to combine

 * slides and
 * live demos

in the terminal.

# How it works

PShT is a shell library that provides a simple and standardized
way to step through slides. Any program or script can serve as a
slide, as long as it's in the `_slides` subdirectory.

The `_slides` folder in the source repository can serve as an
example.

# Inline Markup

- *emphasis* (italics)
- **strong emphasis**
- ***italics and strong***
- [underlined]{.ul}
- [Small caps]{.smallcaps}
- ~~strikeout~~
- H~2~O
- b^+2^
- [Link to pandoc](https://pandoc.org)

# Lists

(1) one
(2) two

I.  primus
II. secundus
III. tertius

apple
:  Company

:  tasty fruit

banana
:  yellow
