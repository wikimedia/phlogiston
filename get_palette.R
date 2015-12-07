library(RColorBrewer)
library(ggthemes)
library(argparse)

suppressPackageStartupMessages(library("argparse"))
parser <- ArgumentParser(formatter_class= 'argparse.RawTextHelpFormatter')

parser$add_argument("size", nargs=1, help="size")

args <- parser$parse_args()

print(args$size)
print(brewer.pal(as.numeric(args$size), "Spectral"))
