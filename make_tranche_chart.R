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

######################################################################
## Velocity
######################################################################

velocity_t <- read.csv(sprintf("/tmp/%s/tranche_velocity.csv", args$project))
velocity_cat_t <- velocity_t[velocity_t$category == args$tranche_name,]
velocity_cat_t$date <- as.Date(velocity_cat_t$date, "%Y-%m-%d")

velocity_points <- read.csv(sprintf("/tmp/%s/tranche_velocity_points.csv", args$project))
velocity_cat_points <- velocity_points[velocity_points$category == args$tranche_name,]
velocity_cat_points$date <- as.Date(velocity_cat_points$date, "%Y-%m-%d")

png(filename = sprintf("~/html/%s_tranche%s_velocity_points.png", args$project, args$tranche_num), width=1000, height=300, units="px", pointsize=10)

ggplot(velocity_cat_points) +
  geom_line(aes(x=date, y=pes_points_vel), size=3, color="darkorange2") +
  geom_line(aes(x=date, y=opt_points_vel), size=3, color="chartreuse3") +
  geom_line(aes(x=date, y=nom_points_vel), size=2, color="gray") +
  geom_bar(data=velocity_cat_t, aes(x=date, y=points), fill="black", size=2, stat="identity") +
  labs(title=sprintf("%s velocity forecasts", args$tranche_name), y="Story Point Total") +
  scale_x_date(limits=c(cutoff_date, now), date_minor_breaks="1 week", label=date_format("%b %d\n%Y"))+
  theme_fivethirtynine() +
  theme(axis.title.x=element_blank())
dev.off()

velocity_count <- read.csv(sprintf("/tmp/%s/tranche_velocity_count.csv", args$project))
velocity_cat_count <- velocity_count[velocity_count$category == args$tranche_name,]
velocity_cat_count$date <- as.Date(velocity_cat_count$date, "%Y-%m-%d")

png(filename = sprintf("~/html/%s_tranche%s_velocity_count.png", args$project, args$tranche_num), width=1000, height=300, units="px", pointsize=10)

ggplot(velocity_cat_count) +
  geom_line(aes(x=date, y=pes_count_vel), size=3, color="darkorange2") +
  geom_line(aes(x=date, y=opt_count_vel), size=3, color="chartreuse3") +
  geom_line(aes(x=date, y=nom_count_vel), size=2, color="gray") +
  geom_bar(data=velocity_cat_t, aes(x=date, y=count), fill="black", size=2, stat="identity") +
  labs(title=sprintf("%s velocity forecasts", args$tranche_name), y="Story Count") +
  scale_x_date(limits=c(cutoff_date, now), date_minor_breaks="1 week", label=date_format("%b %d\n%Y"))+
  theme_fivethirtynine() +
  theme(axis.title.x=element_blank())
dev.off()

######################################################################
## Forecast
######################################################################

forecast <- read.csv(sprintf("/tmp/%s/forecast.csv", args$project))
forecast$date <- as.Date(forecast$date, "%Y-%m-%d")
forecast <- forecast[forecast$category == args$tranche_name,]
png(filename = sprintf("~/html/%s_tranche%s_forecast_points.png", args$project, args$tranche_num), width=1000, height=300, units="px", pointsize=10)

ggplot(forecast) +
  geom_line(aes(x=date, y=pes_points_fore), color="darkorange2", size=3) +
  geom_line(aes(x=date, y=opt_points_fore), color="chartreuse3", size=3) +
  geom_line(aes(x=date, y=nom_points_fore), color="gray", size=2) +
  labs(title=sprintf("%s completion forecast by points", args$tranche_name), y="weeks remaining") +
  scale_x_date(limits=c(cutoff_date, now), date_minor_breaks="1 week", label=date_format("%b %d\n%Y")) +
  scale_y_continuous(limits=c(0,14), breaks=pretty_breaks(n=7), oob=squish) +
  theme_fivethirtynine() +
  theme(legend.title=element_blank())
dev.off()

png(filename = sprintf("~/html/%s_tranche%s_forecast_count.png", args$project, args$tranche_num), width=1000, height=300, units="px", pointsize=10)

ggplot(forecast) +
  geom_line(aes(x=date, y=pes_count_fore), color="darkorange2", size=3) +
  geom_line(aes(x=date, y=opt_count_fore), color="chartreuse3", size=3) +
  geom_line(aes(x=date, y=nom_count_fore), color="gray", size=2) +
  labs(title=sprintf("%s completion forecast by count", args$tranche_name), y="weeks remaining") +
  scale_x_date(limits=c(cutoff_date, now), date_minor_breaks="1 week", label=date_format("%b %d\n%Y"))+
  scale_y_continuous(limits=c(0,14), breaks=pretty_breaks(n=7), oob=squish ) +
  theme_fivethirtynine() +
  theme(legend.title=element_blank())
dev.off()

######################################################################
## Burnup
######################################################################

backlog <- read.csv(sprintf("/tmp/%s/backlog.csv", args$project))
backlog <- backlog[backlog$category==args$tranche_name,]
backlog$date <- as.Date(backlog$date, "%Y-%m-%d")

forecast$xend <- as.Date(forecast$xend, "%Y-%m-%d")

burnup_cat <- read.csv(sprintf("/tmp/%s/burnup_categories.csv", args$project))
burnup_cat <- burnup_cat[burnup_cat$category==args$tranche_name,]
burnup_cat$date <- as.Date(burnup_cat$date, "%Y-%m-%d")

png(filename = sprintf("~/html/%s_tranche%s_burnup_points.png", args$project, args$tranche_num), width=1000, height=700, units="px", pointsize=10)
ggplot(backlog) +
  labs(title=sprintf("%s burnup by points", args$tranche_name), y="Story Point Total") +
  theme(legend.title=element_blank(), axis.title.x=element_blank()) +
  geom_area(position='stack', aes(x = date, y = points, ymin=0), fill=args$color) +
  scale_x_date(limits=c(cutoff_date, now), date_minor_breaks="1 week", label=date_format("%b %d\n%Y")) +
  geom_line(data=burnup_cat, aes(x=date, y=points), size=2) +
  geom_line(data=forecast, aes(x=xend, y=pes_points_yend), color="red", alpha=0.5) +
  geom_line(data=forecast, aes(x=xend, y=nom_points_yend), color="gray", alpha=0.5) +
  geom_line(data=forecast, aes(x=xend, y=opt_points_yend), color="green4", alpha=0.5)
#  geom_segment(aes(x=date, y=points_y, xend=xend, yend=opt_points_yend), data=forecast, color="green4", linetype=1, alpha=0.5)
dev.off()

png(filename = sprintf("~/html/%s_tranche%s_burnup_count.png", args$project, args$tranche_num), width=1000, height=700, units="px", pointsize=10)

ggplot(backlog) +
  labs(title=sprintf("%s burnup by count", args$tranche_name), y="Story Count") +
  theme(legend.title=element_blank(), axis.title.x=element_blank()) +
  geom_area(position='stack', aes(x = date, y = count, ymin=0), fill=args$color) +
  scale_x_date(limits=c(cutoff_date, now), date_minor_breaks="1 week", label=date_format("%b %d\n%Y")) +
  geom_line(data=burnup_cat, aes(x=date, y=count), size=2)
  geom_segment(aes(x=date, y=count_y, xend=xend, yend=pes_count_yend), data=forecast, color="red", linetype=3) +
  geom_segment(aes(x=date, y=count_y, xend=xend, yend=opt_count_yend), data=forecast, color="green", linetype=3)
dev.off()
