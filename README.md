# viberenamer

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

Sometimes when renaming a group of files you want to craft the perfect regular
expression, selecting just the right quantifiers, escapes, and captures,
ensuring that you have the perfect match.  For all the other times, you can
turn to `viberenamer`.

`viberenamer` was primarily born out of sheer laziness when confronted with
having to craft dozens of throwawey regular expressions when tidying up
ancient filesystem cruft.  It was also an opportunity to exercise the new
Foundation Models framework available in macOS Tahoe.  And of course,
`viberenamer` itself was about 95% vibecoded using thge new 
[ChatGPT 5](https://openai.com/gpt-5/) coding assistent provided in the 
latest XCode betas.

`viberenamer` is also quite purposely limited in scope.  There are other tools
that you can use to connect LLMs to your shell to orchestrate arbitrary
command invocations.  But that introduces a signficantly larger burden on the
user to verify the actions being taken.  `viberenamer` presents a proposed
renaming and asks the user to accept or reject the propsal.  If accepted, the
only thing that can happen is that the files will be renamed.

`viberenamer` is also different than tools like
[ai-renamer](https://github.com/ozgrozer/ai-renamer) in that the focus is
purely on the names of the files and on user prompting.  There is no
attempt to understand the file content to inform the renaming.

It is worth emphasizing that, so far, more time was spent writing this
README file than on the actual code.  If you have any doubts, then you
probably should not be using `viberenamer` yet.  Also, as `viberenamer`
makes of Apple's new Foundation Models framework, at this time it can
only be built and run on macOS Tahoe (26) or later.

## Table of contents
 - [Usage](#usage)
 - [Future work](#future-work)
 - [Development](#development)

## Usage

Basic usage is quite straightforward.  You supply a list of files as 
command-line arguments.  It will then request a prompt to guide the renaming.
If the results are acceptable, you can proceed with the renaming.  Otherwise,
you can choose to provide an updated prompt and try again.  Or just exit.

```
❯ viberenamer foo1 foo2 foo3 foo4 foo5 foo6
Checking 6 argument(s) for existence and permissions (cwd: /private/tmp):
✓ Exists: /private/tmp/foo1 (file)
  • Writable file: yes
  • Writable containing directory: yes (/private/tmp)
✓ Exists: /private/tmp/foo2 (file)
  • Writable file: yes
  • Writable containing directory: yes (/private/tmp)
✓ Exists: /private/tmp/foo3 (file)
  • Writable file: yes
  • Writable containing directory: yes (/private/tmp)
✓ Exists: /private/tmp/foo4 (file)
  • Writable file: yes
  • Writable containing directory: yes (/private/tmp)
✓ Exists: /private/tmp/foo5 (file)
  • Writable file: yes
  • Writable containing directory: yes (/private/tmp)
✓ Exists: /private/tmp/foo6 (file)
  • Writable file: yes
  • Writable containing directory: yes (/private/tmp)
Enter your renaming request.
Example: "Rename all files to kebab-case with a 'vibe-' prefix"
> Rename all these files to have the form "Foo-{number}" where number is the numeric portion of the filename.
Proposed renames (6):
foo1 -> Foo-1
foo2 -> Foo-2
foo3 -> Foo-3
foo4 -> Foo-4
foo5 -> Foo-5
foo6 -> Foo-6
Proceed with renaming? Type 'yes' to confirm, or anything else to decline: yes
Renamed: foo1 -> /private/tmp/Foo-1
Renamed: foo2 -> /private/tmp/Foo-2
Renamed: foo3 -> /private/tmp/Foo-3
Renamed: foo4 -> /private/tmp/Foo-4
Renamed: foo5 -> /private/tmp/Foo-5
Renamed: foo6 -> /private/tmp/Foo-6
All files renamed successfully.
❯
```

## Future work

After some experimentation, I found that the current macOS Foundation Models
are not as capable as would be ideal when presented with
 * source filenames that lack relative uniformity,
 * prompts requiring reasoning about character classes.

This is perhaps not surprising given that even 
[state-of-the-art language models struggle with counting letters](https://minimaxir.com/2025/08/llm-blueberry/).
Though regular expressions cannot count either, so perhaps that is being 
unfair. 

I was unable to find a system card or details on Apple's Foundation Model LLM.
It might be possible a "reasoning" model could handle more renaming prompts
better.  On the otherhand, there seems to still be some debate on the 
the [efficacy of chain-of-thought reasoning](https://machinelearning.apple.com/research/illusion-of-thinking)

It might be worth extending `viberenamer` to allow making calls to
[Ollama](https://ollama.com/) to compare performance and behavior with
other models.

Currently, the output of `viberenamer` is a bit verbose.  It would probably
benefit from only reporting failures rather than all the successful checks.

Overall, the `viberenamer` code could benefit from some tasteful human
revision.

## Development

`vibernamer` is currently written in [Swift](https://www.swift.org/) to make
interfacing with Apple's local Foundation Models more straightforward.
Given that it may be worth extending it to support other model providers, it
could make sense to just rewrite it all in [Rust](https://www.rust-lang.org/)
at some point in the future.  That could also make it easier to support
other platforms.

At present, you'll need to be running macOS Tahoe (26) and have an XCode 26
beta installed to build and run `viberenamer`.

Contributions and bug reports are welcome.
