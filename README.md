# pandoc-revealjs-diagram-fragments

Pandoc filter for revealjs target to add syntax for incremental showing diagrams using fragments.

[!IMPORTANT]
This filter makes only sense, if another filter to render the diagrams is also
used later in the filter chain (i.E. [diagram](https://github.com/pandoc-ext/diagram)).

[!WARNING]
For now I created this filter for myself, and it might not have a stable interface.
This might change if other people are interested, but for now I might change the
API without warning to my personal preference at any time.

## Description

When writing revealjs presentations using pandoc, it is often useful to show diagrams in
an incremental way. When the diagrams are written using a "diagram as code" language,
this plugin allows to archive this without re-writing the non-incremental part of the diagram.

To archive this, the [`r-stack`](https://revealjs.com/layout/#stack) together with
[fragments](https://revealjs.com/fragments/) is used.

For example, this code:

````markdown
```{.diagram-type .inc}
diagram-code1
{{ frag() }}
diagram-code2
{{ frag() }}
diagram-code3
```
````

is rendered into something like this:

```
<div class="r-stack">
  <div class="fragment fade-out" data-fragment-index="0">
    diagram-code1
  </div>
  <div class="fragment fade-in-then-out" data-fragment-index="0">
    diagram-code1
    diagram-code2
  </div>
  <div class="fragment fade-in">
    diagram-code1
    diagram-code2
    diagram-code3ion
  </div>
</div>
```

## Usage

First, write your diagrams as described in the syntax section.
Then compile your slide show using pandoc, i.E. like this:

```bash
pandoc presentation.md -t revealjs -s -o index.html \
 --lua-filter=path-to-this-repo/fragment_code_blocks.lua \
 --lua-filter=path-to-diagram-repo/diagram.lua
```

Note, that another filter is needed to convert the diagram code blocks into rendered
diagrams, as this plugin does not do this.

## Syntax

First, add the `inc` or `incremental` class to you digram:

````markdown
```{.plantuml .inc}
diagram-code
```
````

Then, add conditions to the diagrams, which are enclosed in `{{` and `}}`.
A condition always applies to the following code block until the next
condition is met. For every fragment the condition determines if the following
code will be part of that fragment.

Here is a list of conditions:

| Condition code          | Effect                                                                                                                                                                      |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `all()`                 | The code will be included in every fragment.                                                                                                                                |
| `fragment()`            | An internal count on how often this funtion is called is kept. The code will be included in all fragments starting from the fragment where the internal count currently is. |
| `frag()`                | Alias for `fragment()`                                                                                                                                                      |
| `otherwise()`           | The code will be includeded if and only if the last code was not included (alternative for last code block).                                                                |
| `other()`               | Alias for `otherwise()`                                                                                                                                                     |
| `reset_fragment(index)` | Reset the internal count on how often the `fragment()` function has been called to the given index, includes the following code starting from the fragment fiven by index.  |
| `reset_frag(index)`     | Alias for `reset_fragment(index)`                                                                                                                                           |
| `only({i1,i2,...})`     | Only include the code in the fragments, given by the index list.                                                                                                            |
| `except({i1,i2,...})`   | Only include the code in the fragments, not given by the index list.                                                                                                        |
