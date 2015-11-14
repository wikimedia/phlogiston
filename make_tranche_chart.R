#!/usr/bin/env Rscript
# Graph Phlogiston csv reports as charts

library(ggplot2)
library(scales)
library(RColorBrewer)
library(ggthemes)
library(argparse)

suppressPackageStartupMessages(library("argparse"))
parser <- ArgumentParser()

parser$add_argument("project", nargs=1, help="Project prefix")
parser$add_argument("tranche_num", nargs=1, help="Tranche Number")
parser$add_argument("color", nargs=1, help="Color")
parser$add_argument("tranche_name", nargs=1, help="Tranche Name")
parser$add_argument("points_height", nargs=1, help="Points Height")
parser$add_argument("count_height", nargs=1, help="Count Height")

args <- parser$parse_args()

# common theme from https://github.com/Ironholds/wmf/blob/master/R/dataviz.R
theme_fivethirtynine <- function(base_size = 12, base_family = "sans"){
  (theme_foundation(base_size = base_size, base_family = base_family) +
     theme(line = element_line(), rect = element_rect(fill = ggthemes::ggthemes_data$fivethirtyeight["ltgray"],
                                                      linetype = 0, colour = NA),
           text = element_text(size=30, colour = ggthemes::ggthemes_data$fivethirtyeight["dkgray"]),
           axis.title.y = element_text(size = rel(1.5), angle = 90, vjust = 1.5), axis.text = element_text(),
           axis.title.x = element_text(size = rel(1.5)),
           axis.ticks = element_blank(), axis.line = element_blank(),
           panel.grid = element_line(colour = NULL),
           panel.grid.major = element_line(colour = ggthemes_data$fivethirtyeight["medgray"]),
           panel.grid.minor = element_blank(),
           plot.title = element_text(hjust = 0, size = rel(1.5), face = "bold"),
           strip.background = element_rect()))
}

backlog <- read.csv(sprintf("/tmp/%s/backlog.csv", args$project))
backlog$date <- as.Date(backlog$date, "%Y-%m-%d")

burnup_cat <- read.csv(sprintf("/tmp/%s/burnup_categories.csv", args$project))
burnup_cat$date <- as.Date(burnup_cat$date, "%Y-%m-%d")

burnup_output <- png(filename = sprintf("~/html/%s_tranche%s_burnup_points.png", args$project, args$tranche_num), width=1000, height=1125, units="px", pointsize=30)
ggplot(backlog[backlog$category==args$tranche_name,]) + 
   labs(title=sprintf("%s burnup by points", args$tranche_name), y="Story Point Total") +
   theme(text = legend.title=element_blank())+
   geom_area(position='stack', aes(x = date, y = points, ymin=0), fill=args$color) +
   scale_x_date(breaks="1 month", label=date_format("%Y-%b-%d"))+
   scale_y_continuous(limits=c(0, as.numeric(args$points_height))) +
geom_line(data=burnup_cat[burnup_cat$category==args$tranche_name,], aes(x=date, y=points), size=2)
dev.off()

burnup_output <- png(filename = sprintf("~/html/%s_tranche%s_burnup_count.png", args$project, args$tranche_num), width=1000, height=1125, units="px", pointsize=30)
ggplot(backlog[backlog$category==args$tranche_name,]) + 
   labs(title=sprintf("%s burnup by count", args$tranche_name), y="Story Count") +
   theme(text = element_text(size=30), legend.title=element_blank())+
   geom_area(position='stack', aes(x = date, y = count, ymin=0), fill=args$color) +
   scale_x_date(breaks="1 month", label=date_format("%Y-%b-%d"))+
   scale_y_continuous(limits=c(0, as.numeric(args$count_height))) +
geom_line(data=burnup_cat[burnup_cat$category==args$tranche_name,], aes(x=date, y=count), size=2)
dev.off()


