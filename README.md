# fcstats
a simple tool to find out who use the buffer/cache in your system

use [mmap](http://man7.org/linux/man-pages/man2/mmap.2.html) to get the virtual address spaces which is map with the file.
use [mincore](http://man7.org/linux/man-pages/man2/mincore.2.html) to get the page numbers if there are in buffer or cache 
mincore will return a vector that indicates whether pages of the calling process's virtual memory are resident in core (RAM)

**fcstats** use mmap and mincore provide:

* 1.find the top N process by memory usage, and figure out the total buffer or cache they used 

* 2.find all of the files in dirs, and figure out the buffer or cache usage by every file
