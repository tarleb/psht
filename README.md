# PShT

**P**resentations in **Sh**ell and **T**erminal – shush all
distractions, focus on content.

PShT is a tool to run presentations in the terminal, using a
simple one-file-per-slide approach. It comes with tools that make
the creation of presentations simple and convenient, including a
custom pandoc writer to generate slides from Markdown.

## Why?

The biggest feature of PShT is that it allows to combine

- slides and
- live demos

in the terminal: I like to have slides that give structure to a
presentation, but, whenever I talked about command line tools, I
found myself switching to the terminal to demonstrate specific
commands. This was especially true in highly interactive talks,
where questions from the audience are frequent, and best answered
by a live demonstration. I found these switches annoying, and PShT
is my method to scratch this itch, and to have a way to type a
command while still showing a slide.

## How it works

PShT is a shell *function* and *library* that provides a simple
and standardized way to step through slides. Any program or script
can serve as a slide, as long as it's in the `_slides`
subdirectory.

The `_slides` folder in the source repository can serve as an
example.

## What's not working yet

A list of current shortcomings that I'd like to improve:

- [ ] Pure text slides shouldn't have to be in executable files.
- [ ] Tables shouldn't be dropped.
- [ ] Centering isn't working yet.
- [ ] Support for columns is missing.
- [ ] Docs!
- [ ] Generate zip output by default?
- [ ] Use skylighting for code blocks.
- [ ] Improve styling, esp. headings.
