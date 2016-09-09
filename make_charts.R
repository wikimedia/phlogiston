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

parser$add_argument("scope_prefix", nargs=1, help="Scope prefix", default='phl')
parser$add_argument("scope_title", nargs=1, help="Scope title")
parser$add_argument("showhidden", nargs=1, help="If true, show hidden categories")
parser$add_argument("report_date", nargs=1, help="Date of report")
parser$add_argument("current_quarter_start", nargs=1)
parser$add_argument("next_quarter_start", nargs=1)
parser$add_argument("previous_quarter_start", nargs=1)
parser$add_argument("chart_start", nargs=1)
parser$add_argument("chart_end", nargs=1)
parser$add_argument("three_months_ago", nargs=1)

args <- parser$parse_args()

if (args$showhidden == 'True') {
  showhidden_title = " (Showing Hidden)"
  showhidden_suffix = "_showhidden"
} else {
  showhidden_title = ""
  showhidden_suffix = ""
}

velocity_recent_date <- read.csv(sprintf("/tmp/%s/velocity_recent_date.csv", args$scope_prefix))
velocity_recent_date$date <- as.Date(velocity_recent_date$date, "%Y-%m-%d")

now <- as.Date(args$report_date)
now_plus <- now + 4  # Apply 1/2-week fudge factor to make charts show current week
chart_start <- as.Date(args$chart_start)
chart_end   <- as.Date(args$chart_end)
chart_end_plus <- chart_end + 7
previous_quarter_start  <- as.Date(args$previous_quarter_start)
quarter_start  <- as.Date(args$current_quarter_start)
next_quarter_start    <- as.Date(args$next_quarter_start)
three_months_ago <- as.Date(args$three_months_ago)
burn_done_chart_end <- now + 30  # add room for labels

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

if (args$showhidden == 'True') {
  burn_done <- read.csv(sprintf("/tmp/%s/burn_done_showhidden.csv", args$scope_prefix))
  burn_open <- read.csv(sprintf("/tmp/%s/burn_open_showhidden.csv", args$scope_prefix))
} else {
  burn_done <- read.csv(sprintf("/tmp/%s/burn_done.csv", args$scope_prefix))
  burn_open <- read.csv(sprintf("/tmp/%s/burn_open.csv", args$scope_prefix))
}

# + 1 is hack added after db_refactor branch experiment
bd_cat_count <- length(unique(burn_done$category)) + 1
bo_cat_count <- length(unique(burn_open$category)) + 1 

colorCount = max(bd_cat_count, bo_cat_count)
getPalette = colorRampPalette(brewer.pal(12, "Set3"))

burn_done$category <- factor(burn_done$category, levels=rev(unique(burn_done$category)))
burn_done$date <- as.Date(burn_done$date, "%Y-%m-%d")

burn_open$category <- factor(burn_open$category, levels=rev(unique(burn_open$category)))
burn_open$date <- as.Date(burn_open$date, "%Y-%m-%d")
burn_open$points <- burn_open$points * -1
burn_open$count <- burn_open$count * -1
burn_open$label_points <- burn_open$label_points * -1
burn_open$label_count <- burn_open$label_count * -1

max_date = max(burn_done$date, na.rm=TRUE)

bd_labels <- subset(burn_done, date == max_date)
bd_labels_count <- subset(bd_labels, count != 0)
bd_labels_count$label_count <- bd_labels_count$label_count - (bd_labels_count$count / 2)
bd_labels_points <- subset(bd_labels, points != 0)
bd_labels_points$label_points <- bd_labels_points$label_points - (bd_labels_points$points / 2)

bo_labels <- subset(burn_open, date == max_date)
bo_labels_count <- subset(bo_labels, count != 0)
bo_labels_count$label_count <- bo_labels_count$label_count - (bo_labels_count$count / 2)
bo_labels_points <- subset(bo_labels, points != 0)
bo_labels_points$label_points <- bo_labels_points$label_points - (bo_labels_points$points / 2)

bd_ylegend_count <- max(bd_labels_count$label_count, 10)
bd_ylegend_points <- max(bd_labels_points$label_points, 10)
bo_ylegend_count <- min(bo_labels_count$label_count, 10)
bo_ylegend_points <- min(bo_labels_points$label_points, 10)

png(filename = sprintf("~/html/%s_backlog_burnup_points%s.png", args$scope_prefix, showhidden_suffix), width=2000, height=1125, units="px", pointsize=30)


p <- ggplot(burn_done) +
  geom_area(position='stack', aes(x = date, y = points, group=category, fill=category, order=-category)) +
  geom_area(data=burn_open, position='stack', aes(x = date, y = points, group=category, fill=category, order=-category)) +
  theme_fivethirtynine() +
  scale_fill_manual(values=getPalette(colorCount)) +
  scale_x_date(limits=c(previous_quarter_start, burn_done_chart_end), date_minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  theme(legend.position = "none", axis.title.x=element_blank()) +
  guides(col = guide_legend(reverse=TRUE)) +
  labs(title=sprintf("%s Backlog by points%s", args$scope_title, showhidden_title), y="Story Point Total") +
  annotate("text", x=previous_quarter_start, y=bo_ylegend_points, label="Open Tasks", hjust=0, size=10) +
  annotate("text", x=previous_quarter_start, y=bd_ylegend_points, label="Complete Tasks", hjust=0, size=10) +
  geom_hline(aes(yintercept=c(0)), color="black", size=2) +
  labs(fill="Category")



if (nrow(bd_labels_points) > 0 ) {
    p <- p + geom_text(data=bd_labels_points, aes(x=max_date, y=label_points, label=category), size=9, hjust=0)
}

if (nrow(bo_labels_points) > 0 ) {
   p <- p + geom_text(data=bo_labels_points, aes(x=max_date, y=label_points, label=category), size=9, hjust=0)
}
p
dev.off()

png(filename = sprintf("~/html/%s_backlog_burnup_count%s.png", args$scope_prefix, showhidden_suffix), width=2000, height=1125, units="px", pointsize=30)

ggplot(burn_done) +
  geom_area(position='stack', aes(x = date, y = count, group=category, fill=category, order=-category)) +
  geom_area(data=burn_open, position='stack', aes(x = date, y = count, group=category, fill=category, order=-category)) +
  theme_fivethirtynine() +
  scale_fill_manual(values=getPalette(colorCount)) +
  scale_x_date(limits=c(previous_quarter_start, burn_done_chart_end), date_minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  theme(legend.position = "none", axis.title.x=element_blank()) +
  guides(col = guide_legend(reverse=TRUE)) +
  labs(title=sprintf("%s Backlog by count%s", args$scope_title, showhidden_title), y="Task Count Total") +
  annotate("text", x=previous_quarter_start, y=bo_ylegend_count, label="Open Tasks", hjust=0, size=10) +
  annotate("text", x=previous_quarter_start, y=bd_ylegend_count, label="Complete Tasks", hjust=0, size=10) +
  geom_hline(aes(yintercept=c(0)), color="black", size=2) +
  labs(fill="Category") +
  geom_text(data=bd_labels_count, aes(x=max_date, y=label_count, label=category), size=9, hjust=0) +
  geom_text(data=bo_labels_count, aes(x=max_date, y=label_count, label=category), size=9, hjust=0)
dev.off()


######################################################################
## Velocity
######################################################################

velocity <- read.csv(sprintf("/tmp/%s/velocity.csv", args$scope_prefix))
velocity$date <- as.Date(velocity$date, "%Y-%m-%d")

png(filename = sprintf("~/html/%s_velocity_points.png", args$scope_prefix), width=2000, height=1125, units="px", pointsize=30)

ggplot(velocity, aes(date, points)) +
  geom_bar(stat="identity") +
  theme_fivethirtynine() +
  theme(axis.title.x=element_blank()) +
  scale_x_date(limits=c(three_months_ago, now_plus), date_minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  labs(title=sprintf("%s weekly velocity by points", args$scope_title), y="Story Points")
dev.off()

png(filename = sprintf("~/html/%s_velocity_count.png", args$scope_prefix), width=2000, height=1125, units="px", pointsize=30)

ggplot(velocity, aes(date, count)) +
  geom_bar(stat="identity") +
  theme_fivethirtynine() +
  theme(axis.title.x=element_blank()) +
  scale_x_date(limits=c(three_months_ago, now_plus), date_minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  labs(title=sprintf("%s weekly velocity by count", args$scope_title), y="Tasks")
dev.off()

######################################################################
## Forecast
######################################################################

forecast_done <- read.csv(sprintf("/tmp/%s/forecast_done.csv", args$scope_prefix))
forecast <- read.csv(sprintf("/tmp/%s/forecast.csv", args$scope_prefix))
forecast$date <- as.Date(forecast$date, "%Y-%m-%d")
forecast <- forecast[forecast$weeks_old < 5,]


if (args$showhidden == 'False') {
  forecast_done <- forecast_done[forecast_done$display == 't',]
  forecast <- forecast[forecast$display == 't',]
}

forecast_done$resolved_date <- as.Date(forecast_done$resolved_date, "%Y-%m-%d")
forecast_done$category <- paste(sprintf("%02d",forecast_done$sort_order), strtrim(forecast_done$category, 35))


first_cat = forecast_done$category[1]
last_cat = tail(forecast_done$category,1)
done_before_chart <- na.omit(forecast_done[forecast_done$resolved_date <= chart_start, ])
done_during_chart <- na.omit(forecast_done[forecast_done$resolved_date > chart_start, ])
forecast$category <- paste(sprintf("%02d",forecast$sort_order), strtrim(forecast$category, 35))
forecast$pes_points_date <- as.Date(forecast$pes_points_date, "%Y-%m-%d")
forecast$nom_points_date <- as.Date(forecast$nom_points_date, "%Y-%m-%d")
forecast$opt_points_date <- as.Date(forecast$opt_points_date, "%Y-%m-%d")
forecast$pes_count_date <- as.Date(forecast$pes_count_date, "%Y-%m-%d")
forecast$nom_count_date <- as.Date(forecast$nom_count_date, "%Y-%m-%d")
forecast$opt_count_date <- as.Date(forecast$opt_count_date, "%Y-%m-%d")

forecast_current <- forecast[ forecast$weeks_old < 1 & forecast$weeks_old >= 0 & is.na(forecast$pes_points_growviz) ,]

forecast_future_points <- forecast_current[forecast_current$nom_points_date > chart_end,]
forecast_future_count <- forecast_current[forecast_current$nom_count_date > chart_end,]

forecast_never_points <- forecast_current[!is.na(forecast_current$opt_points_date) & is.na(forecast_current$nom_points_date),]
forecast_never_count <- forecast_current[!is.na(forecast_current$opt_count_date) & is.na(forecast_current$nom_count_date),]

forecast_no_data_points <- forecast_current[!(forecast_current$points_resolved > 0) | is.na(forecast_current$points_resolved),]
forecast_no_data_count <- forecast_current[!(forecast_current$count_resolved > 0) | is.na(forecast_current$count_resolved),]

png(filename = sprintf("~/html/%s_forecast_points%s.png", args$scope_prefix, showhidden_suffix), width=2000, height=1125, units="px", pointsize=30)

p <- ggplot(forecast_done) +
  annotate("rect", xmin=first_cat, xmax=last_cat, ymin=quarter_start, ymax=next_quarter_start, fill="white", alpha=0.5) +
  annotate("text", x=forecast_current$category, y=forecast_current$date, label=forecast_current$points_pct_complete, size=10, family="mono", color="blue") +
  annotate("text", x=0.5, y=forecast_current$date, label="Now (% Complete)", size=8, family="mono", color="blue") +
  geom_hline(aes(yintercept=as.numeric(now)), color="blue") +
  geom_point(aes(x=category, y=resolved_date), size=6, shape=18) +
  geom_point(data = forecast_current, aes(x=category, y=nom_points_date), size=5, shape=5, color="Black") +
  geom_text(data = forecast_current, aes(x=category, y=opt_points_date, label=format(opt_points_date, format="optimistic:\n%b %d %Y")), size=8, color="gray") +
  geom_text(data = forecast_current, aes(x=category, y=pes_points_date, label=format(pes_points_date, format="pessimistic:\n%b %d %Y")), size=8, color="gray") +
  geom_text(data = forecast_current, aes(x=category, y=nom_points_date, label=format(nom_points_date, format="%b %d\n%Y")), size=8, color="DarkSlateGray") +
  geom_point(data = forecast_done, aes(x=category, y=chart_start, label=points_total, size=points_total)) +
  scale_size_continuous(range = c(3,15)) +
  scale_x_discrete(limits = rev(forecast_done$category)) +
  scale_y_date(limits=c(chart_start, chart_end_plus), date_minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  coord_flip() +
  theme_fivethirtynine() +
  labs(title=sprintf("%s forecast completion dates based on points velocity%s", args$scope_title, showhidden_title), x="Category") +
  theme(legend.position = "none",
        axis.text.y = element_text(hjust=1),
        axis.title.x = element_blank())

if(nrow(forecast_future_points) > 0) {
   p = p + geom_text(data = forecast_future_points, aes(x=category, y=chart_end_plus, label=format(nom_points_date, format="nominal:\n%b %Y")), size=8, color="SlateGray")
}

if(nrow(done_before_chart) > 0) {
  p = p + geom_text(data = done_before_chart, aes(x=category, y=chart_start, label=format(resolved_date, format="%b %d\n%Y")), size=8)
}

if(nrow(done_during_chart) > 0) {
  p = p + geom_text(data = done_during_chart, aes(x=category, y=resolved_date, label=format(resolved_date, format="%b %d\n%Y")), size=8)
}

if(nrow(forecast_no_data_points) > 0) {
  p = p + geom_text(data = forecast_no_data_points, aes(x=category, y=chart_end_plus, label='Not enough\nvelocity data'), size=8, color="SlateGray")
}

if(nrow(forecast_never_points) > 0) {
  p = p + geom_text(data = forecast_never_points, aes(x=category, y=chart_end_plus, label='nominal:\nNever'), size=8, color="SlateGray")
}

p

png(filename = sprintf("~/html/%s_forecast_count%s.png", args$scope_prefix, showhidden_suffix), width=2000, height=1125, units="px", pointsize=30)

p <- ggplot(forecast_done) +
  annotate("rect", xmin=first_cat, xmax=last_cat, ymin=quarter_start, ymax=next_quarter_start, fill="white", alpha=0.5) +
  annotate("text", x=forecast_current$category, y=forecast_current$date, label=forecast_current$count_pct_complete, size=10, family="mono", color="blue") +
  annotate("text", x=0.5, y=forecast_current$date, label="Now (% Complete)", size=8, family="mono", color="blue") +
  geom_hline(aes(yintercept=as.numeric(now)), color="blue") +
  geom_point(aes(x=category, y=resolved_date), size=6, shape=18) +
  geom_point(data = forecast_current, aes(x=category, y=nom_count_date), size=5, shape=5, color="Black") +
  geom_text(data = forecast_current, aes(x=category, y=opt_count_date, label=format(opt_count_date, format="optimistic:\n%b %d %Y")), size=8, color="gray") +
  geom_text(data = forecast_current, aes(x=category, y=pes_count_date, label=format(pes_count_date, format="pessimistic:\n%b %d %Y")), size=8, color="gray") +
  geom_text(data = forecast_current, aes(x=category, y=nom_count_date, label=format(nom_count_date, format="%b %d\n%Y")), size=8, color="DarkSlateGray") +
  geom_text(data = forecast_done, aes(x=category, y=chart_start, label=count_total, size=count_total)) +
  scale_size_continuous(range = c(5,9)) +
  scale_x_discrete(limits = rev(forecast_done$category)) +
  scale_y_date(limits=c(chart_start, chart_end_plus), date_minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  coord_flip() +
  theme_fivethirtynine() +
  labs(title=sprintf("%s forecast completion dates based on count velocity%s", args$scope_title, showhidden_title), x="Category") +
  theme(legend.position = "none",
        axis.text.y = element_text(hjust=1),
        axis.title.x = element_blank())

if(nrow(forecast_future_count) > 0) {
   p = p + geom_text(data = forecast_future_count, aes(x=category, y=chart_end_plus, label=format(nom_count_date, format="nominal:\n%b %Y")), size=8, color="SlateGray")
}

if(nrow(done_before_chart) > 0) {
  p = p + geom_text(data = done_before_chart, aes(x=category, y=chart_start, label=format(resolved_date, format="%b %d\n%Y")), size=8)
}

if(nrow(done_during_chart) > 0) {
  p = p + geom_text(data = done_during_chart, aes(x=category, y=resolved_date, label=format(resolved_date, format="%b %d\n%Y")), size=8)
}

if(nrow(forecast_no_data_count) > 0) {
  p = p + geom_text(data = forecast_no_data_count, aes(x=category, y=chart_end_plus, label='Not enough\nvelocity data'), size=8, color="SlateGray")
}

if(nrow(forecast_never_count) > 0) {
  p = p + geom_text(data = forecast_never_count, aes(x=category, y=chart_end_plus, label='nominal:\nNever'), size=8, color="SlateGray")
}

p
dev.off()


######################################################################
## Recently Closed
######################################################################

done <- read.csv(sprintf("/tmp/%s/recently_closed.csv", args$scope_prefix))
done$date <- as.Date(done$date, "%Y-%m-%d")
done$category <- paste(sprintf("%02d",done$sort_order), strtrim(done$category, 35))
done$category <- factor(done$category, levels=rev(done$category[order(done$priority)]))

colorCount = length(unique(done$category))
getPalette = colorRampPalette(brewer.pal(9, "YlGn"))

png(filename = sprintf("~/html/%s_done_points.png", args$scope_prefix), width=2000, height=1125, units="px", pointsize=30)
ggplot(done, aes(x=date, y=points, fill=factor(category))) +
  geom_bar(stat="identity")+ 
  scale_fill_manual(values=getPalette(colorCount), name="Category") +
  theme_fivethirtynine() +
  theme(axis.title.x=element_blank()) +
  scale_x_date(limits=c(three_months_ago, now_plus), date_minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  theme(legend.direction='vertical', axis.title.x=element_blank()) +
  labs(title=sprintf("%s Recently Closed work by points", args$scope_title), y="Points", x="Month", aesthetic="Category")
dev.off()

png(filename = sprintf("~/html/%s_done_count.png", args$scope_prefix), width=2000, height=1125, units="px", pointsize=30)
ggplot(done, aes(x=date, y=count, fill=factor(category))) +
  geom_bar(stat="identity") +
  scale_fill_manual(values=getPalette(colorCount), name="Category") +
  theme_fivethirtynine() +
  scale_x_date(limits=c(three_months_ago, now_plus), date_minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  theme(legend.direction='vertical', axis.title.x=element_blank()) +
  labs(title=sprintf("%s Recently Closed work by count", args$scope_title), y="Count", x="Month", aesthetic="Category")
dev.off()

######################################################################
## Maintenance Fraction
######################################################################

## maint_frac <- read.csv(sprintf("/tmp/%s/maintenance_fraction.csv", args$scope_prefix))
## maint_frac$date <- as.Date(maint_frac$date, "%Y-%m-%d")

## status_output <- png(filename = sprintf("~/html/%s_maint_frac.png", args$scope_prefix), width=2000, height=1125, units="px", pointsize=30)

## ggplot(maint_frac, aes(date, maint_frac_points)) +
##   geom_bar(stat="identity") +
##   scale_y_continuous(labels=percent, limits=c(0,1)) +
##   scale_x_date(limits=c(three_months_ago, now), date_minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
##   theme_fivethirtynine() +
##   theme(axis.title.x=element_blank()) +
##   labs(title=sprintf("%s Maintenance Fraction by points", args$scope_title), y="Fraction of completed work that is maintenance")
## dev.off()

## status_output_count <- png(filename = sprintf("~/html/%s_maint_count_frac.png", args$scope_prefix), width=2000, height=1125, units="px", pointsize=30)
## ggplot(maint_frac, aes(date, maint_frac_count)) +
##   geom_bar(stat="identity") +
##   scale_y_continuous(labels=percent, limits=c(0,1)) + 
##   theme_fivethirtynine() +
##   theme(axis.title.x=element_blank()) +
##   scale_x_date(limits=c(three_months_ago, now), date_minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
##   labs(title=sprintf("%s Maintenance Fraction by count", args$scope_title), y="Fraction of completed work that is maintenance")
## dev.off()

maint_prop <- read.csv(sprintf("/tmp/%s/maintenance_proportion.csv", args$scope_prefix))
maint_prop$date <- as.Date(maint_prop$date, "%Y-%m-%d")
maint_prop$maint_type <- factor(maint_prop$maint_type, levels=rev(maint_prop$maint_type[order(maint_prop$maint_type)]))


status_output <- png(filename = sprintf("~/html/%s_maint_prop_points.png", args$scope_prefix), width=2000, height=1125, units="px", pointsize=30)

ggplot(maint_prop, aes(x=date, y=points, fill=factor(maint_type))) +
  geom_bar(stat="identity") +
  scale_fill_brewer(name="Type of work", palette="YlOrBr") +
  scale_x_date(limits=c(three_months_ago, now), date_minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  theme_fivethirtynine() +
  theme(legend.direction='vertical', axis.title.x=element_blank()) +
  labs(title=sprintf("%s Core Fraction type by points", args$scope_title), y="Amount of completed work by type")
dev.off()

status_output <- png(filename = sprintf("~/html/%s_maint_prop_count.png", args$scope_prefix), width=2000, height=1125, units="px", pointsize=30)

ggplot(maint_prop, aes(x=date, y=count, fill=factor(maint_type))) +
  geom_bar(stat="identity") +
  scale_fill_brewer(name="Type of work", palette="YlOrBr") +
  scale_x_date(limits=c(three_months_ago, now), date_minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  theme_fivethirtynine() +
  theme(legend.direction='vertical', axis.title.x=element_blank()) +
  labs(title=sprintf("%s Core Fraction type by count", args$scope_title), y="Amount of completed work by type")
dev.off()

######################################################################
## Points Histogram
######################################################################

points_histogram <- read.csv(sprintf("/tmp/%s/points_histogram.csv", args$scope_prefix))
points_histogram$points <- factor(points_histogram$points)
png(filename = sprintf("~/html/%s_points_histogram.png", args$scope_prefix), width=2000, height=1125, units="px", pointsize=30)

ggplot(points_histogram, aes(points, count)) +
  geom_bar(stat="identity") +
  theme(axis.title.x=element_blank()) +
  facet_grid(priority ~ ., scales="free_y", space="free", margins=TRUE) +
  labs(title=sprintf("%s Number of resolved tasks by points and priority", args$scope_title), y="Count")
dev.off()
