#!/usr/bin/env Rscript
# Graph Phlogiston csv reports as charts

library(ggplot2)
library(scales)
library(RColorBrewer)
library(ggthemes)
library(argparse)

suppressPackageStartupMessages(library("argparse"))
parser <- ArgumentParser(formatter_class= 'argparse.RawTextHelpFormatter')

parser$add_argument("project", nargs=1, help="Project prefix")
parser$add_argument("title", nargs=1, help="Project title")

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

######################################################################
## Backlog
######################################################################

backlog <- read.csv(sprintf("/tmp/%s/backlog.csv", args$project))
backlog$date <- as.Date(backlog$date, "%Y-%m-%d")
backlog_output=png(filename = sprintf("~/html/%s_backlog_burnup.png", args$project), width=2000, height=1125, units="px", pointsize=30)
backlog$category <- factor(backlog$category, levels=rev(backlog$category))

burnup <- read.csv(sprintf("/tmp/%s/burnup.csv", args$project))
burnup$date <- as.Date(burnup$date, "%Y-%m-%d")

ggplot(backlog) +
  geom_area(position='stack', aes(x = date, y = points, group=category, fill=category, order=-as.numeric(category))) +
  geom_line(data=burnup, aes(x=date, y=points), size=2) +
  theme_fivethirtynine() +
  scale_fill_brewer(palette="PuOr") +
  labs(title=sprintf("%s backlog by points", args$title), y="Story Point Total") +
  geom_vline(aes(xintercept=as.numeric(as.Date(c('2015-10-01'))), color="gray"))
dev.off()

backlog_count_output=png(filename = sprintf("~/html/%s_backlog_count_burnup.png", args$project), width=2000, height=1125, units="px", pointsize=30)

ggplot(backlog) +
  geom_area(position='stack', aes(x = date, y = count, group=category, fill=category, order=as.numeric(category))) +
  geom_line(data=burnup, aes(x=date, y=count), size=2) +
  theme_fivethirtynine() +
  scale_fill_brewer(palette="PuOr") +
  labs(title=sprintf("%s backlog by count", args$title), y="Task Count") +
  geom_vline(aes(xintercept=as.numeric(as.Date(c('2015-10-01'))), color="gray"))
dev.off()

######################################################################
## Velocity
######################################################################

velocity <- read.csv(sprintf("/tmp/%s/velocity.csv", args$project))
velocity$date <- as.Date(velocity$date, "%Y-%m-%d")

velocity_output <- png(filename = sprintf("~/html/%s_velocity.png", args$project), width=2000, height=1125, units="px", pointsize=30)

ggplot(velocity, aes(date, velocity_points)) +
  geom_bar(stat="identity") +
  theme_fivethirtynine() +
  labs(title=sprintf("%s weekly velocity by points", args$title), y="Story Points")
dev.off()

velocity_count_output <- png(filename = sprintf("~/html/%s_velocity_count.png", args$project), width=2000, height=1125, units="px", pointsize=30)

ggplot(velocity, aes(date, velocity_count)) +
  geom_bar(stat="identity") +
  theme_fivethirtynine() +
  labs(title=sprintf("%s weekly velocity by count", args$title), y="Tasks")
dev.off()

######################################################################
## Velocity vs backlog
######################################################################

net_growth <- read.csv(sprintf("/tmp/%s/net_growth.csv", args$project))
net_growth$date <- as.Date(net_growth$date, "%Y-%m-%d")

net_growth_output <- png(filename = sprintf("~/html/%s_net_growth.png", args$project), width=2000, height=1125, units="px", pointsize=30)

ggplot(net_growth, aes(date, points)) +
  geom_bar(stat="identity") +
  theme_fivethirtynine() +
  labs(title=sprintf("%s Net change in open backlog by points", args$title), y="Story Points")
dev.off()

######################################################################
## Recently Closed
######################################################################

done <- read.csv(sprintf("/tmp/%s/recently_closed.csv", args$project))
done$date <- as.Date(done$date, "%Y-%m-%d")

done_output <- png(filename = sprintf("~/html/%s_done.png", args$project), width=2000, height=1125, units="px", pointsize=30)
ggplot(done, aes(x=date, y=points, fill=factor(category), order=-as.numeric(category))) +
  geom_bar(stat="identity", width=7) +
  scale_fill_discrete(name="Milestones") + 
  theme_fivethirtynine() +
  labs(title=sprintf("%s Completed work by points", args$title), y="Points", x="Month", aesthetic="Milestone")
dev.off()
done_count_output <- png(filename = sprintf("~/html/%s_done_count.png", args$project), width=2000, height=1125, units="px", pointsize=30)
ggplot(done, aes(x=date, y=count, fill=factor(category), order=-as.numeric(category))) +
  geom_bar(stat="identity", width=7) +
  scale_fill_discrete(name="Milestones") +
  theme_fivethirtynine() +
  labs(title=sprintf("%s Completed work by count", args$title), y="Count", x="Month", aesthetic="Milestone")
dev.off()

######################################################################
## Maintenance Fraction
######################################################################

maint_frac <- read.csv(sprintf("/tmp/%s/maintenance_fraction.csv", args$project))
maint_frac$date <- as.Date(maint_frac$date, "%Y-%m-%d")

status_output <- png(filename = sprintf("~/html/%s_maint_frac.png", args$project), width=2000, height=1125, units="px", pointsize=30)

ggplot(maint_frac, aes(date, maint_frac_points)) +
  geom_bar(stat="identity") +
  scale_y_continuous(labels=percent, limits=c(0,1)) +
  theme_fivethirtynine() +
  labs(title=sprintf("%s Maintenance Fraction by points", args$title), y="Fraction of completed work that is maintenance")
dev.off()

status_output_count <- png(filename = sprintf("~/html/%s_maint_count_frac.png", args$project), width=2000, height=1125, units="px", pointsize=30)
ggplot(maint_frac, aes(date, maint_frac_count)) +
  geom_bar(stat="identity") +
  scale_y_continuous(labels=percent, limits=c(0,1)) + 
  theme_fivethirtynine() +
  labs(title=sprintf("%s Maintenance Fraction by count", args$title), y="Fraction of completed work that is maintenance")
dev.off()
