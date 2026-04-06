# Blaze

Blaze is an operating system designed for fun by me, César Gutiérrez. It's a work in progress and it will be a long way until I can call it a full *operating system* so, by now, let's call it a project.

## What is Blaze capable of?

By now, nearly nothing. It contains a boot sector that loads a binary. When executed, that binary halts the system. It ain't much, but it's honest work.

## Why is it called Blaze?

There are three main reasons:

1. Blaziken is my favourite Pokemon and if I have to name this project after something cool that guy seems a fairly good option to me.
2. I didn't want to name it cesarOS or something like that because it's like creating a fantasy land and naming it "César's Land"... like, come on!
3. It's hard to name software. Have you read [the first explanation](https://github.com/git/git/commit/e83c5163316f89bfbde7d9ab23ca2e25604af290#diff-2b7814d3fca2e99e56c51b6ff2aa313ea6e9da6424804240aa8ad891fdfe0900R4) that Linus Torvalds gave about the name of *git*?

## How do I compile it?

The Makefile has a section called *REQUIRED DEPENDENCIES*, all of the programs in that list have to be installed to compile the system. They should also be in the same place that the variables point to.

If you already have the programs, but they're installed in another directory and you don't want to move them, change the value of the variables. More information about that is provided inside the Makefile.

You can check if any dependency is installed running the value of the variable with the flag `--version`.

After everything has been checked, you can open a terminal in the project's root directory and type `make`. When the execution finishes, open the `build` directory and you'll see a disk image with Blaze installed in it.

### Debugging information

Including debugging information on the compile process can be very useful (especially with GDB), but can increase the size of every object file. That's why, by default, debugging information is *not* included.

If you want to include it, execute `make` setting the `DEBUG` variable to `true`. For example:

```bash
make all DEBUG=true
```

This variable works with every recipe.

### Parallel compilation

Parallel compilation is supported. You should be able execute `make` in parallel threads using `-j` with no problem at all.

This option is also compatible with the `DEBUG` variable mentioned before, like in this example:

```bash
make -j 11 all DEBUG=true
```

## How do I run it?

The Makefile also includes a section called *OPTIONAL DEPENDENCIES*. The programs listed there can be installed to run the targets `qemu` and `debug`.

- The first (*qemu*) emulates the system using the QEMU version for the `i686-elf` architecture.
- The second (*debug*) emulates the system using Bochs and its VNC display. The installed version of Bochs must support the display `rfb`.

Of course, if you want to use another emulator or burn the image to an USB and boot the system on real hardware, you're welcome to do so!

## How do I contribute?

That's a good question. I have no experience working with pull requests or GitHub issues. Putting that aside, if you want to collaborate and know how to do it, I'll be happy to talk, of course.

## Can I fork it or copy it?

Of course! All of the contents in this repository are licensed under the [Creative Commons Attribution 4.0 License](https://creativecommons.org/licenses/by/4.0/). That means you can share and adapt my work as long as you give appropriate credit (read the [deed](https://creativecommons.org/licenses/by/4.0/) in case of doubt).

The legal text of the license is included in the file named `COPYING`.