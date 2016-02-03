#!/usr/bin/env Rscript
# Graph Phlogiston csv reports as charts

library(ggplot2)
library(scales)
library(RColorBrewer)
library(ggthemes)
library(argparse)
library(stringr)

suppressPackageStartupMessages(library("argparse"))
parser <- ArgumentParser(formatter_class= 'argparse.RawTextHelpFormatter')

parser$add_argument("project", nargs=1, help="Project prefix", default='an')
parser$add_argument("title", nargs=1, help="Project title")

args <- parser$parse_args()

now <- Sys.Date()
forecast_start <- as.Date(c("2016-01-01"))
forecast_end   <- as.Date(c("2016-07-01"))
forecast_end_plus <- forecast_end + 10
quarter_start  <- as.Date(c("2016-01-01"))
quarter_end    <- as.Date(c("2016-04-01"))
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
  geom_vline(aes(xintercept=as.numeric(as.Date(c('2016-01-01'))), color="gray"))
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
## plot X first, to get all labels and in the correct order
## forecasts w/error bars
## completed milestones in range
## completed milestones out of range
## forecasts out of range

forecast_done <- read.csv(sprintf("/tmp/%s/forecast_done.csv", args$project))
forecast_done$resolved_date <- as.Date(forecast_done$resolved_date, "%Y-%m-%d")
forecast_done$category <- paste(sprintf("%02d",forecast_done$sort_order), forecast_done$category)
first_cat = forecast_done$category[1]
last_cat = tail(forecast_done$category,1)

done_before_quarter <- na.omit(forecast_done[forecast_done$resolved_date <= quarter_start, ])
done_during_quarter <- na.omit(forecast_done[forecast_done$resolved_date > quarter_start, ])

forecast <- read.csv(sprintf("/tmp/%s/forecast.csv", args$project))
forecast <- forecast[forecast$weeks_old < 5,]
forecast$category <- paste(sprintf("%02d",forecast$sort_order), forecast$category)
forecast$pes_points_date <- as.Date(forecast$pes_points_date, "%Y-%m-%d")
forecast$nom_points_date <- as.Date(forecast$nom_points_date, "%Y-%m-%d")
forecast$opt_points_date <- as.Date(forecast$opt_points_date, "%Y-%m-%d")
forecast$pes_count_date <- as.Date(forecast$pes_count_date, "%Y-%m-%d")
forecast$nom_count_date <- as.Date(forecast$nom_count_date, "%Y-%m-%d")
forecast$opt_count_date <- as.Date(forecast$opt_count_date, "%Y-%m-%d")
forecast_current <- na.omit(forecast[forecast$weeks_old == 1,])
forecast_future_points <- na.omit(forecast[forecast$nom_points_date > forecast_end & forecast$weeks_old == 1, ])
forecast_future_count <- na.omit(forecast[forecast$nom_count_date > forecast_end & forecast$weeks_old == 1, ])

png(filename = sprintf("~/html/%s_forecast.png", args$project), width=2000, height=1125, units="px", pointsize=30)

p <- ggplot(forecast_done) +
  geom_rect(aes(xmin=first_cat, xmax=last_cat, ymin=quarter_start, ymax=quarter_end), fill="white", alpha=0.05) +
  geom_hline(aes(yintercept=as.numeric(now)), color="blue") +
  geom_point(aes(x=category, y=resolved_date), size=8, shape=18) +
  geom_errorbar(data = forecast, aes(x=category, y=nom_points_date, ymax=pes_points_date, ymin=opt_points_date, color=weeks_old), width=.3, size=2, position="dodge", alpha=.2) +
  geom_point(data = forecast, aes(x=category, y=nom_points_date, color=weeks_old), size=10, shape=5) +
  geom_point(data = forecast_current, aes(x=category, y=nom_points_date), size=13, shape=5, color="Black") +
  geom_text(data = forecast_current, aes(x=category, y=nom_points_date, label=format(nom_points_date, format="%b %d\n%Y")), size=8, shape=5, color="DarkSlateGray") +
  scale_x_discrete(limits = rev(forecast_done$category)) +
  scale_y_date(limits=c(forecast_start, forecast_end_plus), minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  coord_flip() +
  theme_fivethirtynine() +
  labs(title=sprintf("%s forecast completion dates based on points velocity", args$title), x="Milestones (high priority on top)") +
  theme(legend.position = "none",
        axis.text.y = element_text(hjust=1),
        axis.title.x = element_blank())

if(nrow(forecast_future_points) > 0) {
   p = p + geom_text(data = forecast_future_points, aes(x=category, y=forecast_end_plus, label=format(nom_points_date, format="nominal\n%b %Y")), size=8, color="SlateGray")
}

if(nrow(done_before_quarter) > 0) {
  p = p + geom_text(data = done_before_quarter, aes(x=category, y=quarter_start, label=format(resolved_date, format="%b %d\n%Y")), size=8)
}

if(nrow(done_during_quarter) > 0) {
  p = p + geom_text(data = done_during_quarter, aes(x=category, y=resolved_date, label=format(resolved_date, format="%b %d\n%Y")), size=8)
}
p
dev.off()

png(filename = sprintf("~/html/%s_forecast_count.png", args$project), width=2000, height=1125, units="px", pointsize=30)

p <- ggplot(forecast_done) +
  geom_rect(aes(xmin=first_cat, xmax=last_cat, ymin=quarter_start, ymax=quarter_end), fill="white", alpha=0.05) +
  geom_hline(aes(yintercept=as.numeric(now)), color="blue") +
  geom_point(aes(x=category, y=resolved_date), size=8, shape=18) +
  geom_errorbar(data = forecast, aes(x=category, y=nom_count_date, ymax=pes_count_date, ymin=opt_count_date, color=weeks_old), width=.3, size=2, position="dodge", alpha=.2) +
  geom_point(data = forecast, aes(x=category, y=nom_count_date, color=weeks_old), size=10, shape=5) +
  geom_point(data = forecast_current, aes(x=category, y=nom_count_date), size=13, shape=5, color="Black") +
  geom_text(data = forecast_current, aes(x=category, y=nom_count_date, label=format(nom_count_date, format="%b %d\n%Y")), size=8, shape=5, color="DarkSlateGray") +
  scale_x_discrete(limits = rev(forecast_done$category)) +
  scale_y_date(limits=c(forecast_start, forecast_end_plus), minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  coord_flip() +
  theme_fivethirtynine() +
  labs(title=sprintf("%s forecast completion dates based on count velocity", args$title), x="Milestones (high priority on top)") +
  theme(legend.position = "none",
        axis.text.y = element_text(hjust=1),
        axis.title.x = element_blank())

if(nrow(forecast_future_count) > 0) {
  p = p + geom_text(data = forecast_future_count, aes(x=category, y=forecast_end_plus, label=format(nom_count_date, format="nominal\n%b %Y")), size=8, color="SlateGray")
}

if(nrow(done_before_quarter) > 0) {
  p = p + geom_text(data = done_before_quarter, aes(x=category, y=quarter_start, label=format(resolved_date, format="%b %d\n%Y")), size=8)
}

if(nrow(done_during_quarter) > 0) {
  p = p + geom_text(data = done_during_quarter, aes(x=category, y=resolved_date, label=format(resolved_date, format="%b %d\n%Y")), size=8)
}
p
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
  theme(legend.position='bottom', legend.direction='vertical', axis.title.x=element_blank()) +
  labs(title=sprintf("%s Core/Strat type by points", args$title), y="Amount of completed work by type")
dev.off()

status_output <- png(filename = sprintf("~/html/%s_maint_prop_count.png", args$project), width=2000, height=1125, units="px", pointsize=30)

ggplot(maint_prop, aes(x=date, y=count, fill=factor(maint_type))) +
  geom_bar(stat="identity") +
  scale_fill_brewer(name="Type of work", palette="YlOrBr") +
  scale_x_date(limits=c(three_months_ago, now), minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  theme_fivethirtynine() +
  theme(legend.position='bottom', legend.direction='vertical', axis.title.x=element_blank()) +
  labs(title=sprintf("%s Core/Strat type by count", args$title), y="Amount of completed work by type")
dev.off()

######################################################################
## Points Histogram
######################################################################

points_histogram <- read.csv(sprintf("/tmp/%s/points_histogram.csv", args$project))

png(filename = sprintf("~/html/%s_points_histogram.png", args$project), width=2000, height=1125, units="px", pointsize=30)

ggplot(points_histogram, aes(points, count)) +
  geom_bar(stat="identity") +
  theme_fivethirtynine() +
  theme(axis.title.x=element_blank()) +
  labs(title=sprintf("%s Number of resolved tasks by points", args$title), y="Count")
dev.off()
