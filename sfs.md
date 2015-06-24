# Introduction #

A simple FileSystem classes to allow accessing heterogeneus filesystems.

# Details #

  * Directory _(local FileSystem)_
  * Iso _(reading and writting isos)_
  * ZipArchive _(reading zip archives with uncompressed/deflated and lzma methods)_

To avoid lzma method compile using -version=no\_lzma. Lzma method requires link with lzma.d and LzmaDec.obj. Can be found at the svn _(/trunk/lzma)_