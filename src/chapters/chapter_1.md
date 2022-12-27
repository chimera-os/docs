# **Building and installing software from Source on Linux**

*This chapter uses material from **Mendel Cooper, Building and Installing Software Packages for Linux (1999)**, The Linux Documentation Project ([https://tldp.org/HOWTO/Software-Building-HOWTO.html#toc17](https://tldp.org/HOWTO/Software-Building-HOWTO.html#toc17)) and **Beginner's Guide to Installing from Source**, [http://moi.vonos.net/linux/beginners-installing-from-source/](http://moi.vonos.net/linux/beginners-installing-from-source/)*

## Verifying the integrity and signature of a file

When we download software, we need to verify two things before installing: The integrity of the software and its authenticity. **This is extremely important since using damaged or (worse) infected softwares can have disastrous effects on your machine or the software you are trying to build**.

For that purpose we use *checksums* (see [Wikipedia](https://en.wikipedia.org/wiki/Checksum) for more information). All Linux distribution provide at least `md5sum`, `sha1sum` and `sha256sum` to generate checksums. Use `gpg`-keys to check the signature of a file. This task is usually done by your package manager, but when installing from source, this is your responsability to check if you have downloaded the right package. Read [https://www.linux.org/threads/verify-your-downloads-integrity-and-signatures.34282/](https://www.linux.org/threads/verify-your-downloads-integrity-and-signatures.34282/) for detailled instructions on how to check the signature and checksums of a file.

---

## Unpacking archives using `tar` & `gzip`

To unpack archives (or "tarballs"), use the [`tar`](https://www.gnu.org/software/tar/) utility by typing `tar xvf <filename>`. Remove the `v` option to silence the output. This works for `tar.gz`, `tar.xz` and `.bz2` archives. Alternatively you can use `gzip -cd <filename> | tar xvf -`.

---

## Applying patches using `patch` & `diff`

Sometimes you may need to apply patches to the source code of the downloaded archive. Usually a *patchfile* is provided if needed. As example we will use the following files :

### Finding the difference between the content of two files or folders

To find the difference between `file1.txt` and `file2.txt`, use `diff -u file1.txt file2.txt`. The output highlights the differences. To produce a *patchfile*, use `diff -u file1.txt file2.txt > file.patch`. Use `diff -ruN folder1/ folder2/ > file.patch` when comparing two folders. See the [related man-page](https://man7.org/linux/man-pages/man1/diff.1.html) for more information on `diff`.

### Applying a patch on files or folders

For a single file, use `patch` as `patch -u -b <target> -i <patchfile>`. The `b` option creates a backup of the target file before making the modifications. To patch a folder, use `patch --dry-run -ruN -d <target> < <patchfile>` before patching to allow `patch` to run checks (with the `dry-run` options). The `d` option specifies which directory we want to work on. Run `patch -ruN -d <target> < <patchfile>` to apply it. See the [related man-page](https://man7.org/linux/man-pages/man1/patch.1.html) for more information on `patch`.
