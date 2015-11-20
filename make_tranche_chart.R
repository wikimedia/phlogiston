#!/usr/bin/env Rscript
# Graph Phlogiston csv reports as charts

library(ggplot2)
library(scales)
library(RColorBrewer)
library(ggthemes)
library(argparse)
library(reshape)

suppressPackageStartupMessages(library("argparse"))
parser <- ArgumentParser()

parser$add_argument("project", nargs=1, help="Project prefix")
parser$add_argument("tranche_num", nargs=1, help="Tranche Number")
parser$add_argument("color", nargs=1, help="Color")
parser$add_argument("tranche_name", nargs=1, help="Tranche Name")
parser$add_argument("points_height", nargs=1, help="Points Height")
parser$add_argument("count_height", nargs=1, help="Count Height")

args <- parser$parse_args()

now <- Sys.Date()
cutoff_date <- now - 91

# common theme from https://github.com/Ironholds/wmf/blob/master/R/dataviz.R
theme_fivethirtynine <- function(base_size = 12, base_family = "sans"){
  (theme_foundation(base_size = base_size, base_family = base_family) +
     theme(line = element_line(), rect = element_rect(fill = ggthemes::ggthemes_data$fivethirtyeight["ltgray"],
                                                      linetype = 0, colour = NA),
           text = element_text(size=10, colour = ggthemes::ggthemes_data$fivethirtyeight["dkgray"]),
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

burnup_output <- png(filename = sprintf("~/html/%s_tranche%s_burnup_points.png", args$project, args$tranche_num), width=1000, height=700, units="px", pointsize=10)
ggplot(backlog[backlog$category==args$tranche_name,]) + 
   labs(title=sprintf("%s burnup by points", args$tranche_name), y="Story Point Total") +
   theme(legend.title=element_blank())+
   geom_area(position='stack', aes(x = date, y = points, ymin=0), fill=args$color) +
   scale_x_date(limits=c(cutoff_date, now), minor_breaks="1 week", label=date_format("%b %d %Y"))+
   scale_y_continuous(limits=c(0, as.numeric(args$points_height))) +
geom_line(data=burnup_cat[burnup_cat$category==args$tranche_name,], aes(x=date, y=points), size=2)
dev.off()

burnup_output <- png(filename = sprintf("~/html/%s_tranche%s_burnup_count.png", args$project, args$tranche_num), width=1000, height=700, units="px", pointsize=10)

ggplot(backlog[backlog$category==args$tranche_name,]) + 
   labs(title=sprintf("%s burnup by count", args$tranche_name), y="Story Count") +
   theme(legend.title=element_blank())+
   geom_area(position='stack', aes(x = date, y = count, ymin=0), fill=args$color) +
   scale_x_date(limits=c(cutoff_date, now), minor_breaks="1 week", label=date_format("%b %d %Y"))+
   scale_y_continuous(limits=c(0, as.numeric(args$count_height))) +
geom_line(data=burnup_cat[burnup_cat$category==args$tranche_name,], aes(x=date, y=count), size=2)
dev.off()

velocity_cat_points <- read.csv(sprintf("/tmp/%s/tranche_velocity_points.csv", args$project))
velocity_cat_points$date <- as.Date(velocity_cat_points$date, "%Y-%m-%d")
velocity_output <- png(filename = sprintf("~/html/%s_tranche%s_velocity_points.png", args$project, args$tranche_num), width=1000, height=700, units="px", pointsize=10)
velocity_cat_points <- velocity_cat_points[velocity_cat_points$category == args$tranche_name,]
vlong_points <- melt(velocity_cat_points, id=c("date", "category"))
velocity_t <- read.csv(sprintf("/tmp/%s/tranche_velocity.csv", args$project))
velocity_t$date <- as.Date(velocity_t$date, "%Y-%m-%d")

ggplot(vlong_points) +
   geom_bar(data=velocity_t[velocity_t$category == args$tranche_name,], aes(x=date, y=points), fill="gray", size=2, stat="identity") +
   geom_line(aes(x=date, y=value, group=variable), size=3, color="black") +
   labs(title=sprintf("%s velocity forecasts", args$tranche_name), y="Story Point Total") +
   scale_x_date(limits=c(cutoff_date, now), minor_breaks="1 week", label=date_format("%b %d %Y"))+
   theme_fivethirtynine()
dev.off()

velocity_cat_count <- read.csv(sprintf("/tmp/%s/tranche_velocity_count.csv", args$project))
velocity_cat_count$date <- as.Date(velocity_cat_count$date, "%Y-%m-%d")
velocity_output <- png(filename = sprintf("~/html/%s_tranche%s_velocity_count.png", args$project, args$tranche_num), width=1000, height=700, units="px", pointsize=10)
velocity_cat_count <- velocity_cat_count[velocity_cat_count$category == args$tranche_name,]
vlong_count <- melt(velocity_cat_count, id=c("date", "category"))

ggplot(vlong_count) +
   geom_bar(data=velocity_t[velocity_t$category == args$tranche_name,], aes(x=date, y=count), fill="gray", size=2, stat="identity") +
   geom_line(aes(x=date, y=value, group=variable), size=3, color="black") +
   labs(title=sprintf("%s velocity forecasts", args$tranche_name), y="Story Count") +
   scale_x_date(limits=c(cutoff_date, now), minor_breaks="1 week", label=date_format("%b %d %Y"))+
   theme_fivethirtynine()
dev.off()

forecast <- read.csv(sprintf("/tmp/%s/forecast.csv", args$project))
forecast$date <- as.Date(forecast$date, "%Y-%m-%d")
forecast <- forecast[forecast$category == args$tranche_name,]
forecast_points_output <- png(filename = sprintf("~/html/%s_tranche%s_forecast_points.png", args$project, args$tranche_num), width=1000, height=700, units="px", pointsize=10)

ggplot(forecast) +
   geom_line(aes(x=date, y=pes_points_fore), size=1, color="red") +
   geom_line(aes(x=date, y=nom_points_fore), size=3, color="gray") +
   geom_line(aes(x=date, y=opt_points_fore), size=1, color="green") +
   labs(title=sprintf("%s completion forecast by points", args$tranche_name), y="weeks remaining") +
   scale_x_date(limits=c(cutoff_date, now), minor_breaks="1 week", label=date_format("%b %d %Y")) +
   scale_y_continuous(limits=c(0,14), breaks=pretty_breaks(n=7)) +
theme_fivethirtynine()
dev.off()

forecast_count_output <- png(filename = sprintf("~/html/%s_tranche%s_forecast_count.png", args$project, args$tranche_num), width=1000, height=700, units="px", pointsize=10)

ggplot(forecast) +
   geom_line(aes(x=date, y=pes_count_fore), size=1, color="red") +
   geom_line(aes(x=date, y=nom_count_fore), size=3, color="gray") +
   geom_line(aes(x=date, y=opt_count_fore), size=1, color="green") +
   labs(title=sprintf("%s completion forecast by count", args$tranche_name), y="weeks remaining") +
   scale_x_date(limits=c(cutoff_date, now), minor_breaks="1 week", label=date_format("%b %d %Y"))+
   scale_y_continuous(limits=c(0,14), breaks=pretty_breaks(n=7) ) +
   theme_fivethirtynine()
dev.off()

