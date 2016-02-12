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
parser$add_argument("zoom", nargs=1, help="If true, show only zoomed categories")

args <- parser$parse_args()

if (args$zoom == 'True') {
  zoom_title = " (Zoomed)"
  zoom_suffix = "_zoom"
} else {
  zoom_title = ""
  zoom_suffix = ""
}
now <- Sys.Date()
forecast_start <- as.Date(c("2016-01-01"))
forecast_end   <- as.Date(c("2016-07-01"))
forecast_end_plus <- forecast_end + 7
last_quarter_start  <- as.Date(c("2015-10-01"))
quarter_start  <- as.Date(c("2016-01-01"))
next_quarter_start    <- as.Date(c("2016-04-01"))
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

## ######################################################################
## ## Backlog
## ######################################################################

## backlog <- read.csv(sprintf("/tmp/%s/backlog.csv", args$project))
## if (args$zoom == 'True') {
##   backlog <- backlog[backlog$zoom == 't',]
##   burnup <- read.csv(sprintf("/tmp/%s/burnup_zoom.csv", args$project))
## } else {
##   burnup <- read.csv(sprintf("/tmp/%s/burnup.csv", args$project))
## }

## backlog$category <- factor(backlog$category, levels=rev(unique(backlog$category)))
## backlog$date <- as.Date(backlog$date, "%Y-%m-%d")
## burnup$date <- as.Date(burnup$date, "%Y-%m-%d")

## png(filename = sprintf("~/html/%s_backlog_burnup_points%s.png", args$project, zoom_suffix), width=2000, height=1125, units="px", pointsize=30)

## ggplot(backlog) +
##   geom_area(position='stack', aes(x = date, y = points, group=category, fill=category, order=-category)) +
##   theme_fivethirtynine() +
##   scale_fill_brewer(palette="Set3") +
##   scale_x_date(limits=c(three_months_ago, now), minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
##   theme(legend.direction='vertical', axis.title.x=element_blank()) +
##   guides(col = guide_legend(reverse=TRUE)) +
##   labs(title=sprintf("%s backlog by points%s", args$title, zoom_title), y="Story Point Total") +
##   geom_vline(aes(xintercept=as.numeric(as.Date(c('2016-01-01'))), color="gray")) +
##   labs(fill="Milestone")
## dev.off()

## png(filename = sprintf("~/html/%s_backlog_burnup_count%s.png", args$project, zoom_suffix), width=2000, height=1125, units="px", pointsize=30)

## ggplot(backlog) +
##   geom_area(position='stack', aes(x = date, y = count, group=category, fill=category, order=-category)) +
##   theme_fivethirtynine() +
##   scale_fill_brewer(palette="Set3") + 
##   scale_x_date(limits=c(three_months_ago, now), minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
##   theme(legend.direction='vertical', axis.title.x=element_blank()) +
##   guides(col = guide_legend(reverse=TRUE)) +
##   labs(title=sprintf("%s backlog by count%s", args$title, zoom_title), y="Task Count") +
##   geom_vline(aes(xintercept=as.numeric(as.Date(c('2016-01-01'))), color="gray")) +
##   labs(fill="Milestone")
## dev.off()

######################################################################
## Backlog - EXPERIMENTAL
######################################################################

burn_done <- read.csv(sprintf("/tmp/%s/burn_done.csv", args$project))
burn_open <- read.csv(sprintf("/tmp/%s/burn_open.csv", args$project))

if (args$zoom == 'True') {
  burn_done <- burn_done[burn_done$zoom == 't',]
  burn_open <- burn_open[burn_open$zoom == 't',]
}

burn_done$category <- factor(burn_done$category, levels=rev(unique(burn_done$category)))
burn_done$date <- as.Date(burn_done$date, "%Y-%m-%d")
burn_open$date <- as.Date(burn_open$date, "%Y-%m-%d")
burn_open$points <- burn_open$points * -1
burn_open$count <- burn_open$count * -1

max_date = max(burn_done$date, na.rm=TRUE)
bd_labels <- subset(burn_done, date == max_date)
bd_labels = bd_labels[with(bd_labels, order(category, levels(bd_labels$category))),]
bd_labels_count <- subset(bd_labels, count != 0)
bd_labels_count$label_count <- bd_labels_count$label_count * -1
bd_labels_points <- subset(bd_labels, points != 0)
bd_labels_points$label_points <- bd_labels_points$label_points * -1
print(burn_open)
print(bd_labels_count)
png(filename = sprintf("~/html/%s_backlog_burnup_points%s.png", args$project, zoom_suffix), width=2000, height=1125, units="px", pointsize=30)

ggplot(burn_done) +
  geom_area(position='stack', aes(x = date, y = points, group=category, fill=category, order=-category)) +
  geom_area(data=burn_open, position='stack', aes(x = date, y = points, group=category, fill=category, order=-category)) +
  theme_fivethirtynine() +
  scale_fill_brewer(palette="Set3") +
  scale_x_date(limits=c(last_quarter_start, next_quarter_start), minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  theme(legend.direction='vertical', axis.title.x=element_blank()) +
  guides(col = guide_legend(reverse=TRUE)) +
  labs(title=sprintf("%s Backlog by points%s", args$title, zoom_title), y="Story Point Total") +
  annotate("text", x=quarter_start, y=20, label="Done") +
  annotate("text", x=quarter_start, y=-20, label="Open") +
  geom_vline(aes(xintercept=as.numeric(as.Date(quarter_start)), color="gray")) +
  geom_hline(aes(yintercept=c(0)), color="black", size=2) +
  labs(fill="Milestone") +
  geom_text(data=bd_labels_points, aes(x=max_date, y=label_points, label=category)) +
  theme(axis.text.x=element_text(angle=-25, hjust=0.5, size = 8))
dev.off()

png(filename = sprintf("~/html/%s_backlog_burnup_count%s.png", args$project, zoom_suffix), width=2000, height=1125, units="px", pointsize=30)

ggplot(burn_done) +
  geom_area(position='stack', aes(x = date, y = count, group=category, fill=category, order=-category)) +
  geom_area(data=burn_open, position='stack', aes(x = date, y = count, group=category, fill=category, order=-category)) +
  theme_fivethirtynine() +
  scale_fill_brewer(palette="Set3") +
  scale_x_date(limits=c(last_quarter_start, next_quarter_start), minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  theme(legend.direction='vertical', axis.title.x=element_blank()) +
  guides(col = guide_legend(reverse=TRUE)) +
  labs(title=sprintf("%s Backlog by count%s", args$title, zoom_title), y="Task Count Total (Done above 0, Open below 0") +
  annotate("text", x=quarter_start, y=100, label="Done") +
  annotate("text", x=quarter_start, y=-100, label="Open") +
  geom_vline(aes(xintercept=as.numeric(as.Date(quarter_start)), color="gray")) +
  geom_hline(aes(yintercept=c(0)), color="black", size=3) +
  labs(fill="Milestone") +
  geom_text(data=bd_labels_count, aes(x=max_date, y=label_count, label=category)) +
  theme(axis.text.x=element_text(angle=-25, hjust=0.5, size = 8))
dev.off()


######################################################################
## Velocity
######################################################################

velocity <- read.csv(sprintf("/tmp/%s/velocity.csv", args$project))
velocity$date <- as.Date(velocity$date, "%Y-%m-%d")

png(filename = sprintf("~/html/%s_velocity_points.png", args$project), width=2000, height=1125, units="px", pointsize=30)

ggplot(velocity, aes(date, points)) +
  geom_bar(stat="identity") +
  theme_fivethirtynine() +
  theme(axis.title.x=element_blank()) +
  scale_x_date(limits=c(three_months_ago, now), minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  labs(title=sprintf("%s weekly velocity by points", args$title), y="Story Points")
dev.off()

png(filename = sprintf("~/html/%s_velocity_count.png", args$project), width=2000, height=1125, units="px", pointsize=30)

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

forecast_done <- read.csv(sprintf("/tmp/%s/forecast_done.csv", args$project))
forecast <- read.csv(sprintf("/tmp/%s/forecast.csv", args$project))
forecast <- forecast[forecast$weeks_old < 5,]

if (args$zoom == 'True') {
  forecast_done <- forecast_done[forecast_done$zoom == 't',]
  forecast <- forecast[forecast$zoom == 't',]
}

forecast_done$resolved_date <- as.Date(forecast_done$resolved_date, "%Y-%m-%d")
forecast_done$category <- paste(sprintf("%02d",forecast_done$sort_order), strtrim(forecast_done$category, 35))
first_cat = forecast_done$category[1]
last_cat = tail(forecast_done$category,1)
done_before_quarter <- na.omit(forecast_done[forecast_done$resolved_date <= quarter_start, ])
done_during_quarter <- na.omit(forecast_done[forecast_done$resolved_date > quarter_start, ])
forecast$category <- paste(sprintf("%02d",forecast$sort_order), strtrim(forecast$category, 35))
forecast$pes_points_date <- as.Date(forecast$pes_points_date, "%Y-%m-%d")
forecast$nom_points_date <- as.Date(forecast$nom_points_date, "%Y-%m-%d")
forecast$opt_points_date <- as.Date(forecast$opt_points_date, "%Y-%m-%d")
forecast$pes_count_date <- as.Date(forecast$pes_count_date, "%Y-%m-%d")
forecast$nom_count_date <- as.Date(forecast$nom_count_date, "%Y-%m-%d")
forecast$opt_count_date <- as.Date(forecast$opt_count_date, "%Y-%m-%d")
forecast_current <- na.omit(forecast[forecast$weeks_old == 0,])
forecast_future_points <- na.omit(forecast[forecast$nom_points_date > forecast_end & forecast$weeks_old == 1, ])
forecast_future_count <- na.omit(forecast[forecast$nom_count_date > forecast_end & forecast$weeks_old == 1, ])

png(filename = sprintf("~/html/%s_forecast_points%s.png", args$project, zoom_suffix), width=2000, height=1125, units="px", pointsize=30)

p <- ggplot(forecast_done) +
  geom_rect(aes(xmin=first_cat, xmax=last_cat, ymin=quarter_start, ymax=next_quarter_start), fill="white", alpha=0.09) +
  geom_hline(aes(yintercept=as.numeric(now)), color="blue") +
  geom_point(aes(x=category, y=resolved_date), size=8, shape=18) +
  geom_errorbar(data = forecast, aes(x=category, y=nom_points_date, ymax=pes_points_date, ymin=opt_points_date, color=weeks_old), width=.3, size=2, position="dodge", alpha=.2) +
  geom_point(data = forecast, aes(x=category, y=nom_points_date, color=weeks_old), size=10, shape=5) +
  geom_point(data = forecast_current, aes(x=category, y=nom_points_date), size=13, shape=5, color="Black") +
  geom_text(data = forecast_current, aes(x=category, y=nom_points_date, label=format(nom_points_date, format="%b %d\n%Y")), size=8, shape=5, color="DarkSlateGray") +
  geom_point(data = forecast_done, aes(x=category, y=forecast_start, label=points_total, size=points_total)) +
  scale_size_continuous(range = c(3,15)) +
  scale_x_discrete(limits = rev(forecast_done$category)) +
  scale_y_date(limits=c(forecast_start, forecast_end_plus), minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  coord_flip() +
  theme_fivethirtynine() +
  labs(title=sprintf("%s forecast completion dates based on points velocity%s", args$title, zoom_title), x="Milestone") +
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

png(filename = sprintf("~/html/%s_forecast_count%s.png", args$project, zoom_suffix), width=2000, height=1125, units="px", pointsize=30)

p <- ggplot(forecast_done) +
  geom_rect(aes(xmin=first_cat, xmax=last_cat, ymin=quarter_start, ymax=next_quarter_start), fill="white", alpha=0.09) +
  geom_hline(aes(yintercept=as.numeric(now)), color="blue") +
  geom_point(aes(x=category, y=resolved_date), size=8, shape=18) +
  geom_errorbar(data = forecast, aes(x=category, y=nom_count_date, ymax=pes_count_date, ymin=opt_count_date, color=weeks_old), width=.3, size=2, position="dodge", alpha=.2) +
  geom_point(data = forecast, aes(x=category, y=nom_count_date, color=weeks_old), size=10, shape=5) +
  geom_point(data = forecast_current, aes(x=category, y=nom_count_date), size=13, shape=5, color="Black") +
  geom_text(data = forecast_current, aes(x=category, y=nom_count_date, label=format(nom_count_date, format="%b %d\n%Y")), size=8, shape=5, color="DarkSlateGray") +
  geom_text(data = forecast_done, aes(x=category, y=forecast_start, label=count_total, size=log(count_total))) +
  scale_size_continuous(range = c(2,8)) +
  scale_x_discrete(limits = rev(forecast_done$category)) +
  scale_y_date(limits=c(forecast_start, forecast_end_plus), minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  coord_flip() +
  theme_fivethirtynine() +
  labs(title=sprintf("%s forecast completion dates based on count velocity%s", args$title, zoom_title), x="Milestone") +
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

png(filename = sprintf("~/html/%s_net_growth_points.png", args$project), width=2000, height=1125, units="px", pointsize=30)

ggplot(net_growth, aes(date, points)) +
  geom_bar(stat="identity") +
  theme_fivethirtynine() +
  theme(axis.title.x=element_blank()) +
  scale_x_date(limits=c(three_months_ago, now), minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
labs(title=sprintf("%s Net change in open backlog by points", args$title), y="Story Points")
dev.off()

png(filename = sprintf("~/html/%s_net_growth_count.png", args$project), width=2000, height=1125, units="px", pointsize=30)

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
done$category <- paste(sprintf("%02d",done$sort_order), strtrim(done$category, 35))
done$category <- factor(done$category, levels=rev(done$category[order(done$priority)]))

colorCount = length(unique(done$category))
getPalette = colorRampPalette(brewer.pal(9, "YlGn"))

png(filename = sprintf("~/html/%s_done_points.png", args$project), width=2000, height=1125, units="px", pointsize=30)
ggplot(done, aes(x=date, y=points, fill=factor(category))) +
  geom_bar(stat="identity")+ 
  scale_fill_manual(values=getPalette(colorCount), name="Milestone") +
  theme_fivethirtynine() +
  theme(axis.title.x=element_blank()) +
  scale_x_date(limits=c(three_months_ago, now), minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  theme(legend.direction='vertical', axis.title.x=element_blank()) +
  labs(title=sprintf("%s Completed work by points", args$title), y="Points", x="Month", aesthetic="Milestone")
dev.off()

png(filename = sprintf("~/html/%s_done_count.png", args$project), width=2000, height=1125, units="px", pointsize=30)
ggplot(done, aes(x=date, y=count, fill=factor(category))) +
  geom_bar(stat="identity") +
  scale_fill_manual(values=getPalette(colorCount), name="Milestone") +
  theme_fivethirtynine() +
  scale_x_date(limits=c(three_months_ago, now), minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  theme(legend.direction='vertical', axis.title.x=element_blank()) +
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


status_output <- png(filename = sprintf("~/html/%s_maint_prop_points.png", args$project), width=2000, height=1125, units="px", pointsize=30)

ggplot(maint_prop, aes(x=date, y=points, fill=factor(maint_type))) +
  geom_bar(stat="identity") +
  scale_fill_brewer(name="Type of work", palette="YlOrBr") +
  scale_x_date(limits=c(three_months_ago, now), minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  theme_fivethirtynine() +
  theme(legend.direction='vertical', axis.title.x=element_blank()) +
  labs(title=sprintf("%s Core Fraction type by points", args$title), y="Amount of completed work by type")
dev.off()

status_output <- png(filename = sprintf("~/html/%s_maint_prop_count.png", args$project), width=2000, height=1125, units="px", pointsize=30)

ggplot(maint_prop, aes(x=date, y=count, fill=factor(maint_type))) +
  geom_bar(stat="identity") +
  scale_fill_brewer(name="Type of work", palette="YlOrBr") +
  scale_x_date(limits=c(three_months_ago, now), minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  theme_fivethirtynine() +
  theme(legend.direction='vertical', axis.title.x=element_blank()) +
  labs(title=sprintf("%s Core Fraction type by count", args$title), y="Amount of completed work by type")
dev.off()

######################################################################
## Points Histogram
######################################################################

points_histogram <- read.csv(sprintf("/tmp/%s/points_histogram.csv", args$project))
points_histogram$points <- factor(points_histogram$points)
png(filename = sprintf("~/html/%s_points_histogram.png", args$project), width=2000, height=1125, units="px", pointsize=30)

ggplot(points_histogram, aes(points, count)) +
  geom_bar(stat="identity") +
  theme(axis.title.x=element_blank()) +
  facet_grid(priority ~ ., scales="free_y", space="free", margins=TRUE) +
  labs(title=sprintf("%s Number of resolved tasks by points and priority", args$title), y="Count")
dev.off()
