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

now <- Sys.Date()
forecast_start <- as.Date(c("2016-01-01"))
forecast_end <- as.Date(c("2016-09-30"))
three_months_ago <- now - 91

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
backlog$category <- factor(backlog$category, levels=rev(unique(backlog$category)))
burnup <- read.csv(sprintf("/tmp/%s/burnup.csv", args$project))
burnup$date <- as.Date(burnup$date, "%Y-%m-%d")

ggplot(backlog) +
  geom_area(position='stack', aes(x = date, y = points, group=category, fill=category, order=-category)) +
  geom_line(data=burnup, aes(x=date, y=points), size=2) +
  theme_fivethirtynine() +
  scale_fill_brewer(palette="Set3") +
  scale_x_date(limits=c(three_months_ago, now), minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  theme(legend.position='bottom', legend.direction='vertical', axis.title.x=element_blank()) +
  guides(col = guide_legend(reverse=TRUE)) +
  labs(title=sprintf("%s backlog by points", args$title), y="Story Point Total") +
  geom_vline(aes(xintercept=as.numeric(as.Date(c('2015-10-01'))), color="gray"))
dev.off()

backlog_count_output=png(filename = sprintf("~/html/%s_backlog_count_burnup.png", args$project), width=2000, height=1125, units="px", pointsize=30)

ggplot(backlog) +
  geom_area(position='stack', aes(x = date, y = count, group=category, fill=category, order=-category)) +
  geom_line(data=burnup, aes(x=date, y=count), size=2) +
  theme_fivethirtynine() +
  scale_fill_brewer(palette="Set3") + 
  scale_x_date(limits=c(three_months_ago, now), minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  theme(legend.position='bottom', legend.direction='vertical', axis.title.x=element_blank()) +
  guides(col = guide_legend(reverse=TRUE)) +
  labs(title=sprintf("%s backlog by count", args$title), y="Task Count") +
  geom_vline(aes(xintercept=as.numeric(as.Date(c('2015-10-01'))), color="gray")) +
  geom_vline(aes(xintercept=as.numeric(as.Date(c('2016-01-01'))), color="gray"))
dev.off()

######################################################################
## Velocity
######################################################################

velocity <- read.csv(sprintf("/tmp/%s/velocity.csv", args$project))
velocity$date <- as.Date(velocity$date, "%Y-%m-%d")

velocity_points_output <- png(filename = sprintf("~/html/%s_velocity.png", args$project), width=2000, height=1125, units="px", pointsize=30)

ggplot(velocity, aes(date, points)) +
  geom_bar(stat="identity") +
  theme_fivethirtynine() +
  theme(axis.title.x=element_blank()) +
  scale_x_date(limits=c(three_months_ago, now), minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  labs(title=sprintf("%s weekly velocity by points", args$title), y="Story Points")
dev.off()

velocity_count_output <- png(filename = sprintf("~/html/%s_velocity_count.png", args$project), width=2000, height=1125, units="px", pointsize=30)

ggplot(velocity, aes(date, count)) +
  geom_bar(stat="identity") +
  theme_fivethirtynine() +
  theme(axis.title.x=element_blank()) +
  scale_x_date(limits=c(three_months_ago, now), minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  labs(title=sprintf("%s weekly velocity by count", args$title), y="Tasks")
dev.off()

######################################################################
## Forecast
######################################################################

forecast <- read.csv(sprintf("/tmp/%s/current_forecast.csv", args$project))
forecast$pes_points_date <- as.Date(forecast$pes_points_date, "%Y-%m-%d")
forecast$nom_points_date <- as.Date(forecast$nom_points_date, "%Y-%m-%d")
forecast$opt_points_date <- as.Date(forecast$opt_points_date, "%Y-%m-%d")
forecast$pes_count_date <- as.Date(forecast$pes_count_date, "%Y-%m-%d")
forecast$nom_count_date <- as.Date(forecast$nom_count_date, "%Y-%m-%d")
forecast$opt_count_date <- as.Date(forecast$opt_count_date, "%Y-%m-%d")

forecast$category = strtrim(forecast$category, 35)
forecast$category <- factor(forecast$category, levels=forecast$category[order(rev(forecast$sort_order))])
forecast_points_output  <- png(filename = sprintf("~/html/%s_forecast.png", args$project), width=2000, height=1125, units="px", pointsize=30)

ggplot(forecast, aes(category, nom_points_date, ymax=pes_points_date, ymin=opt_points_date)) +
  geom_point(stat="identity", aes(size=25)) +
  geom_errorbar(aes(size=15), width=.5) +
  geom_hline(aes(yintercept=as.numeric(now)), color="blue") +
  scale_y_date(limits=c(forecast_start, forecast_end), minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  coord_flip() +
  theme_fivethirtynine() +
  labs(title=sprintf("%s forecast completion dates based on points velocity", args$title), x="Milestones (high priority on top)") +
  theme(legend.position = "none",
        axis.text.y = element_text(hjust=1),
        axis.title.x = element_blank())
dev.off()

forecast_count_output  <- png(filename = sprintf("~/html/%s_forecast_count.png", args$project), width=2000, height=1125, units="px", pointsize=30)

ggplot(forecast, aes(category, nom_count_date, ymax=pes_count_date, ymin=opt_count_date)) +
  geom_point(stat="identity", aes(size=25)) +
  geom_errorbar(aes(size=15), width=.5) +
  geom_hline(aes(yintercept=as.numeric(now)), color="blue") +
  scale_y_date(limits=c(forecast_start, forecast_end), minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  coord_flip() +
  theme_fivethirtynine() +
  labs(title=sprintf("%s forecast completion dates based on count velocity", args$title), x="Milestones (high priority on top)") +
  theme(legend.position = "none",
        axis.text.y = element_text(hjust=1),
        axis.title.x = element_blank())
dev.off()

######################################################################
## Velocity vs backlog
######################################################################

net_growth <- read.csv(sprintf("/tmp/%s/net_growth.csv", args$project))
net_growth$date <- as.Date(net_growth$date, "%Y-%m-%d")

net_growth_points_output <- png(filename = sprintf("~/html/%s_net_growth_points.png", args$project), width=2000, height=1125, units="px", pointsize=30)

ggplot(net_growth, aes(date, points)) +
  geom_bar(stat="identity") +
  theme_fivethirtynine() +
  theme(axis.title.x=element_blank()) +
  scale_x_date(limits=c(three_months_ago, now), minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
labs(title=sprintf("%s Net change in open backlog by points", args$title), y="Story Points")
dev.off()

net_growth_count_output <- png(filename = sprintf("~/html/%s_net_growth_count.png", args$project), width=2000, height=1125, units="px", pointsize=30)

ggplot(net_growth, aes(date, count)) +
  geom_bar(stat="identity") +
  theme_fivethirtynine() +
  theme(axis.title.x=element_blank()) +
  scale_x_date(limits=c(three_months_ago, now), minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  labs(title=sprintf("%s Net change in open backlog by count", args$title), y="Task Count")
dev.off()

######################################################################
## Recently Closed
######################################################################

done <- read.csv(sprintf("/tmp/%s/recently_closed.csv", args$project))
done$date <- as.Date(done$date, "%Y-%m-%d")
done$category <- factor(done$category, levels=rev(done$category[order(done$priority)]))

done_output <- png(filename = sprintf("~/html/%s_done.png", args$project), width=2000, height=1125, units="px", pointsize=30)
ggplot(done, aes(x=date, y=points, fill=factor(category))) +
  geom_bar(stat="identity")+ 
  scale_fill_brewer(name="(Priority) Milestone", palette="PuBuGn") +
  theme_fivethirtynine() +
  theme(axis.title.x=element_blank()) +
  scale_x_date(limits=c(three_months_ago, now), minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  theme(legend.position='bottom', legend.direction='vertical', axis.title.x=element_blank()) +
  labs(title=sprintf("%s Completed work by points", args$title), y="Points", x="Month", aesthetic="Milestone")
dev.off()

done_count_output <- png(filename = sprintf("~/html/%s_done_count.png", args$project), width=2000, height=1125, units="px", pointsize=30)
ggplot(done, aes(x=date, y=count, fill=factor(category))) +
  geom_bar(stat="identity") +
  scale_fill_brewer(name="(Priority) Milestone:", palette="PuBuGn") +
  theme_fivethirtynine() +
  scale_x_date(limits=c(three_months_ago, now), minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  theme(legend.position='bottom', legend.direction='vertical', axis.title.x=element_blank()) +
  labs(title=sprintf("%s Completed work by count", args$title), y="Count", x="Month", aesthetic="Milestone")
dev.off()

######################################################################
## Maintenance Fraction
######################################################################

## maint_frac <- read.csv(sprintf("/tmp/%s/maintenance_fraction.csv", args$project))
## maint_frac$date <- as.Date(maint_frac$date, "%Y-%m-%d")

## status_output <- png(filename = sprintf("~/html/%s_maint_frac.png", args$project), width=2000, height=1125, units="px", pointsize=30)

## ggplot(maint_frac, aes(date, maint_frac_points)) +
##   geom_bar(stat="identity") +
##   scale_y_continuous(labels=percent, limits=c(0,1)) +
##   scale_x_date(limits=c(three_months_ago, now), minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
##   theme_fivethirtynine() +
##   theme(axis.title.x=element_blank()) +
##   labs(title=sprintf("%s Maintenance Fraction by points", args$title), y="Fraction of completed work that is maintenance")
## dev.off()

## status_output_count <- png(filename = sprintf("~/html/%s_maint_count_frac.png", args$project), width=2000, height=1125, units="px", pointsize=30)
## ggplot(maint_frac, aes(date, maint_frac_count)) +
##   geom_bar(stat="identity") +
##   scale_y_continuous(labels=percent, limits=c(0,1)) + 
##   theme_fivethirtynine() +
##   theme(axis.title.x=element_blank()) +
##   scale_x_date(limits=c(three_months_ago, now), minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
##   labs(title=sprintf("%s Maintenance Fraction by count", args$title), y="Fraction of completed work that is maintenance")
## dev.off()

maint_prop <- read.csv(sprintf("/tmp/%s/maintenance_proportion.csv", args$project))
maint_prop$date <- as.Date(maint_prop$date, "%Y-%m-%d")
maint_prop$maint_type <- factor(maint_prop$maint_type, levels=rev(maint_prop$maint_type[order(maint_prop$maint_type)]))


status_output <- png(filename = sprintf("~/html/%s_maint_prop.png", args$project), width=2000, height=1125, units="px", pointsize=30)

ggplot(maint_prop, aes(x=date, y=points, fill=factor(maint_type))) +
  geom_bar(stat="identity") +
  scale_fill_brewer(name="Type of work", palette="YlOrBr") +
  scale_x_date(limits=c(three_months_ago, now), minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  theme_fivethirtynine() +
  theme(axis.title.x=element_blank()) +
  labs(title=sprintf("%s Core/Strat type by points", args$title), y="Amount of completed work by type")
dev.off()

status_output <- png(filename = sprintf("~/html/%s_maint_prop_count.png", args$project), width=2000, height=1125, units="px", pointsize=30)

ggplot(maint_prop, aes(x=date, y=count, fill=factor(maint_type))) +
  geom_bar(stat="identity") +
  scale_fill_brewer(name="Type of work", palette="YlOrBr") +
  scale_x_date(limits=c(three_months_ago, now), minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  theme_fivethirtynine() +
  theme(axis.title.x=element_blank()) +
  labs(title=sprintf("%s Core/Strat type by count", args$title), y="Amount of completed work by type")
dev.off()
