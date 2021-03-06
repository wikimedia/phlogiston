#!/usr/bin/env Rscript
# Graph Phlogiston csv reports as charts

library(ggplot2)
library(scales)
library(RColorBrewer)
library(ggthemes)
library(argparse)
library(stringr)

oldw <- getOption("warn")
options(warn = -1)
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

now <- as.Date(args$report_date)
now_plus <- now + 4  # Apply 1/2-week fudge factor to make charts show current week
input_chart_start <- as.Date(args$chart_start)
input_chart_end   <- as.Date(args$chart_end)
chart_end_plus <- input_chart_end + 7  # cosmetic room
previous_quarter_start  <- as.Date(args$previous_quarter_start)
current_quarter_start  <- as.Date(args$current_quarter_start)
next_quarter_start    <- as.Date(args$next_quarter_start)
three_months_ago <- as.Date(args$three_months_ago)
if (args$showhidden == 'True') {
  burn_done_chart_end <- now + 120  # add extra room for labels due to chart zoom out
  burn_done_chart_end_lastq <- current_quarter_start + 45
} else {
  burn_done_chart_end <- now + 30  # add room for labels
  burn_done_chart_end_lastq <- current_quarter_start + 30
}

# common theme from https://github.com/Ironholds/wmf/blob/master/R/dataviz.R
theme_fivethirtynine <- function(base_size = 12, base_family = "sans"){
  (theme_foundation(base_size = base_size, base_family = base_family) +
     theme(line = element_line(), rect = element_rect(fill = "#F0F0F0",
                                                      linetype = 0, colour = NA),
           text = element_text(size=30, colour = "#3C3C3C"),
           axis.title.y = element_text(size = rel(1.5), angle = 90, vjust = 1.5), axis.text = element_text(),
           axis.title.x = element_text(size = rel(1.5)),
           axis.ticks = element_blank(), axis.line = element_blank(),
           panel.grid = element_line(colour = NULL),
           panel.grid.major = element_line(colour = "#D2D2D2"),
           panel.grid.minor = element_blank(),
           plot.title = element_text(hjust = 0, size = rel(1.5), face = "bold"),
           strip.background = element_rect()))
}

######################################################################
## Backlog
######################################################################

# Load data
if (args$showhidden == 'True') {
  burn_done <- read.csv(sprintf("/tmp/%s/burn_done_showhidden.csv", args$scope_prefix))
  burn_open <- read.csv(sprintf("/tmp/%s/burn_open_showhidden.csv", args$scope_prefix))
} else {
  burn_done <- read.csv(sprintf("/tmp/%s/burn_done.csv", args$scope_prefix))
  burn_open <- read.csv(sprintf("/tmp/%s/burn_open.csv", args$scope_prefix))
}

# Munge the data the way R wants it
# + 1 is hack added after db_refactor branch experiment
bd_cat_count <- length(unique(burn_done$category)) + 1
bo_cat_count <- length(unique(burn_open$category)) + 1 
burn_done$category <- factor(burn_done$category, levels=rev(unique(burn_done$category)))
burn_done$date <- as.Date(burn_done$date, "%Y-%m-%d")
burn_open$category <- factor(burn_open$category, levels=rev(unique(burn_open$category)))
burn_open$date <- as.Date(burn_open$date, "%Y-%m-%d")

# Prepare the palette
# Another +1 hack, fixes https://phabricator.wikimedia.org/T150980, no idea why it's necessary.
colorCount = max(bd_cat_count, bo_cat_count) + 1
getPalette = colorRampPalette(brewer.pal(12, "Set3"))

# move open data below the X axis
burn_open$points <- burn_open$points * -1
burn_open$count <- burn_open$count * -1
burn_open$label_points <- burn_open$label_points * -1
burn_open$label_count <- burn_open$label_count * -1

# Define boundaries
range_end = max(burn_done$date, na.rm=TRUE)
# if burn_done is empty, get date from burn_open.  Otherwise, burn_open labels will be missing too.
if (is.null(nrow(range_end))) {
   range_end = max(burn_open$date, na.rm=TRUE)
}

chart_start = input_chart_start
chart_end = burn_done_chart_end

# Prepare the labels
bd_labels <- subset(burn_done, date == range_end)
bd_labels_count <- subset(bd_labels, count != 0)
bd_labels_count$label_count <- bd_labels_count$label_count - (bd_labels_count$count / 2)
bd_labels_points <- subset(bd_labels, points != 0)
bd_labels_points$label_points <- bd_labels_points$label_points - (bd_labels_points$points / 2)

bo_labels <- subset(burn_open, date == range_end)
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
  geom_area(data=burn_open, position='stack', aes(x = date, y = points, group=category, fill=category, order=-category)) +
  theme_fivethirtynine() +
  scale_fill_manual(values=getPalette(colorCount)) +
  scale_x_date(limits=c(chart_start, chart_end), date_minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  theme(legend.position = "none", axis.title.x=element_blank()) +
  guides(col = guide_legend(reverse=TRUE)) +
  labs(title=sprintf("%s Backlog by points%s", args$scope_title, showhidden_title), y="Story Point Total") +
  annotate("text", x=chart_start, y=bo_ylegend_points, label="Open Tasks", hjust=0, size=10) +
  annotate("text", x=chart_start, y=bd_ylegend_points, label="Complete Tasks", hjust=0, size=10) +
  geom_hline(aes(yintercept=c(0)), color="black", size=2) +
  labs(fill="Category")

if (nrow(burn_done) > 0 ) {
   p <- p + geom_area(position='stack', aes(x = date, y = points, group=category, fill=category, order=-category))
}

if (nrow(bd_labels_points) > 0 ) {
    p <- p + geom_text(data=bd_labels_points, aes(x=range_end, y=label_points, label=category), size=9, hjust=0)
}

if (nrow(bo_labels_points) > 0 ) {
   p <- p + geom_text(data=bo_labels_points, aes(x=range_end, y=label_points, label=category), size=9, hjust=0)
}

p
dev.off()

png(filename = sprintf("~/html/%s_backlog_burnup_count%s.png", args$scope_prefix, showhidden_suffix), width=2000, height=1125, units="px", pointsize=30)

p <- ggplot(burn_done) +
  geom_area(data=burn_open, position='stack', aes(x = date, y = count, group=category, fill=category, order=-category)) +
  theme_fivethirtynine() +
  scale_fill_manual(values=getPalette(colorCount)) +
  scale_x_date(limits=c(chart_start, chart_end), date_minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  theme(legend.position = "none", axis.title.x=element_blank()) +
  guides(col = guide_legend(reverse=TRUE)) +
  labs(title=sprintf("%s Backlog by count%s", args$scope_title, showhidden_title), y="Task Count Total") +
  annotate("text", x=chart_start, y=bo_ylegend_count, label="Open Tasks", hjust=0, size=10) +
  annotate("text", x=chart_start, y=bd_ylegend_count, label="Complete Tasks", hjust=0, size=10) +
  geom_hline(aes(yintercept=c(0)), color="black", size=2) +
  labs(fill="Category")

if (nrow(burn_done) > 0 ) {
   p <- p + geom_area(position='stack', aes(x = date, y = count, group=category, fill=category, order=-category))
}

if (nrow(bd_labels_count) > 0 ) {
    p <- p + geom_text(data=bd_labels_count, aes(x=range_end, y=label_count, label=category), size=9, hjust=0)
}

if (nrow(bo_labels_count) > 0 ) {
   p <- p + geom_text(data=bo_labels_count, aes(x=range_end, y=label_count, label=category), size=9, hjust=0)
}

p
dev.off()


######################################################################
## Backlog Last Quarter
######################################################################

# Load data
# burn_open can be re-used
burn_open <- subset(burn_open, date <= current_quarter_start)

# Define boundaries
range_start <- previous_quarter_start
range_end <- current_quarter_start

# Chart boundaries bigger than data plot boundaries to leave room for labels
chart_start <- previous_quarter_start 
chart_end <- burn_done_chart_end_lastq

# burn_done data must come from a different source
if (args$showhidden == 'True') {
  burn_done <- read.csv(sprintf("/tmp/%s/burn_done_showhidden_lastq.csv", args$scope_prefix))
} else {
  burn_done <- read.csv(sprintf("/tmp/%s/burn_done_lastq.csv", args$scope_prefix))
}

# Munge the data the way R wants it
# + 1 is hack added after db_refactor branch experiment
bd_cat_count <- length(unique(burn_done$category)) + 1
burn_done$category <- factor(burn_done$category, levels=rev(unique(burn_done$category)))
burn_done$date <- as.Date(burn_done$date, "%Y-%m-%d")

# Make sure data ends at the right time
burn_done <- subset(burn_done, date <= range_end)

# Prepare the palette
# Another +1 hack, fixes https://phabricator.wikimedia.org/T150980, no idea why it's necessary.
colorCount = max(bd_cat_count, bo_cat_count) + 1
getPalette = colorRampPalette(brewer.pal(12, "Set3"))


# Prepare the labels
bd_labels <- subset(burn_done, date == range_end)
bd_labels_count <- subset(bd_labels, count != 0)
bd_labels_count$label_count <- bd_labels_count$label_count - (bd_labels_count$count / 2)
bd_labels_points <- subset(bd_labels, points != 0)
bd_labels_points$label_points <- bd_labels_points$label_points - (bd_labels_points$points / 2)

bo_labels <- subset(burn_open, date == range_end)
bo_labels_count <- subset(bo_labels, count != 0)
bo_labels_count$label_count <- bo_labels_count$label_count - (bo_labels_count$count / 2)
bo_labels_points <- subset(bo_labels, points != 0)
bo_labels_points$label_points <- bo_labels_points$label_points - (bo_labels_points$points / 2)

bd_ylegend_count <- max(bd_labels_count$label_count, 10)
bd_ylegend_points <- max(bd_labels_points$label_points, 10)
bo_ylegend_count <- min(bo_labels_count$label_count, 10)
bo_ylegend_points <- min(bo_labels_points$label_points, 10)

png(filename = sprintf("~/html/%s_backlog_burnup_points_lastq%s.png", args$scope_prefix, showhidden_suffix), width=2000, height=1125, units="px", pointsize=30)

p <- ggplot(burn_done) +
  geom_area(data=burn_open, position='stack', aes(x = date, y = points, group=category, fill=category, order=-category)) +
  theme_fivethirtynine() +
  scale_fill_manual(values=getPalette(colorCount)) +
  scale_x_date(limits=c(chart_start, chart_end), date_minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  theme(legend.position = "none", axis.title.x=element_blank()) +
  guides(col = guide_legend(reverse=TRUE)) +
  labs(title=sprintf("%s Backlog by points%s (Last Quarter)", args$scope_title, showhidden_title), y="Story Point Total") +
  annotate("text", x=chart_start, y=bo_ylegend_points, label="Open Tasks", hjust=0, size=10) +
  annotate("text", x=chart_start, y=bd_ylegend_points, label="Complete Tasks", hjust=0, size=10) +
  geom_hline(aes(yintercept=c(0)), color="black", size=2) +
  labs(fill="Category")

if (nrow(burn_done) > 0 ) {
   p <- p + geom_area(position='stack', aes(x = date, y = points, group=category, fill=category, order=-category))
}

if (nrow(bd_labels_points) > 0 ) {
    p <- p + geom_text(data=bd_labels_points, aes(x=range_end, y=label_points, label=category), size=9, hjust=0)
}

if (nrow(bo_labels_points) > 0 ) {
   p <- p + geom_text(data=bo_labels_points, aes(x=range_end, y=label_points, label=category), size=9, hjust=0)
}

p
dev.off()

png(filename = sprintf("~/html/%s_backlog_burnup_count_lastq%s.png", args$scope_prefix, showhidden_suffix), width=2000, height=1125, units="px", pointsize=30)

p <- ggplot(burn_done) +
  geom_area(data=burn_open, position='stack', aes(x = date, y = count, group=category, fill=category, order=-category)) +
  theme_fivethirtynine() +
  scale_fill_manual(values=getPalette(colorCount)) +
  scale_x_date(limits=c(chart_start, chart_end), date_minor_breaks="1 month", label=date_format("%b %d\n%Y")) +
  theme(legend.position = "none", axis.title.x=element_blank()) +
  guides(col = guide_legend(reverse=TRUE)) +
  labs(title=sprintf("%s Backlog by count%s (Last Quarter)", args$scope_title, showhidden_title), y="Task Count Total") +
  annotate("text", x=chart_start, y=bo_ylegend_count, label="Open Tasks", hjust=0, size=10) +
  annotate("text", x=chart_start, y=bd_ylegend_count, label="Complete Tasks", hjust=0, size=10) +
  geom_hline(aes(yintercept=c(0)), color="black", size=2) +
  labs(fill="Category")

if (nrow(burn_done) > 0 ) {
   p <- p + geom_area(position='stack', aes(x = date, y = count, group=category, fill=category, order=-category))
}

if (nrow(bd_labels_count) > 0 ) {
    p <- p + geom_text(data=bd_labels_count, aes(x=range_end, y=label_count, label=category), size=9, hjust=0)
}

if (nrow(bo_labels_count) > 0 ) {
   p <- p + geom_text(data=bo_labels_count, aes(x=range_end, y=label_count, label=category), size=9, hjust=0)
}

p
dev.off()

######################################################################
## Forecast
######################################################################

forecast_done <- read.csv(sprintf("/tmp/%s/forecast_done.csv", args$scope_prefix))
forecast <- read.csv(sprintf("/tmp/%s/forecast.csv", args$scope_prefix))
forecast$date <- as.Date(forecast$date, "%Y-%m-%d")
forecast <- forecast[forecast$weeks_old < 5,]

chart_start = current_quarter_start - 30
chart_end <- input_chart_end

if (args$showhidden == 'False') {
  forecast_done <- forecast_done[forecast_done$display == 'show',]
  forecast <- forecast[forecast$display == 'show',]
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
  annotate("rect", xmin=first_cat, xmax=last_cat, ymin=current_quarter_start, ymax=next_quarter_start, fill="white", alpha=0.5) +
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
  annotate("rect", xmin=first_cat, xmax=last_cat, ymin=current_quarter_start, ymax=next_quarter_start, fill="white", alpha=0.5) +
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
## Velocity
######################################################################

done_w <- read.csv(sprintf("/tmp/%s/recently_closed_week.csv", args$scope_prefix))
done_w$date <- as.Date(done_w$date, "%Y-%m-%d")
done_w$category <- paste(sprintf("%02d",done_w$sort_order), strtrim(done_w$category, 35))
done_w$category <- factor(done_w$category, levels=rev(done_w$category[order(done_w$sort_order)]))

colorCount = length(unique(done_w$category))
getPalette = colorRampPalette(brewer.pal(9, "YlGn"))

png(filename = sprintf("~/html/%s_done_points.png", args$scope_prefix), width=2000, height=1125, units="px", pointsize=30)
ggplot(done_w, aes(x=date, y=points, fill=factor(category))) +
  geom_bar(stat="identity")+ 
  scale_fill_manual(values=getPalette(colorCount), name="Category") +
  theme_fivethirtynine() +
  theme(axis.title.x=element_blank()) +
  theme(legend.direction='vertical', axis.title.x=element_blank()) +
  labs(title=sprintf("%s Velocity by weekly points", args$scope_title), y="Points", x="Month", aesthetic="Category")
dev.off()

png(filename = sprintf("~/html/%s_done_count.png", args$scope_prefix), width=2000, height=1125, units="px", pointsize=30)
ggplot(done_w, aes(x=date, y=count, fill=factor(category))) +
  geom_bar(stat="identity") +
  scale_fill_manual(values=getPalette(colorCount), name="Category") +
  theme_fivethirtynine() +
  theme(legend.direction='vertical', axis.title.x=element_blank()) +
  labs(title=sprintf("%s Velocity by weekly count", args$scope_title), y="Count", x="Month", aesthetic="Category")
dev.off()

done_m <- read.csv(sprintf("/tmp/%s/recently_closed_month.csv", args$scope_prefix))
done_m$date <- as.Date(done_m$date, "%Y-%m-%d")
done_m$category <- paste(sprintf("%02d",done_m$sort_order), strtrim(done_m$category, 35))
done_m$category <- factor(done_m$category, levels=rev(done_m$category[order(done_m$sort_order)]))

colorCount = length(unique(done_m$category))
getPalette = colorRampPalette(brewer.pal(9, "YlGn"))

png(filename = sprintf("~/html/%s_done_m_points.png", args$scope_prefix), width=2000, height=1125, units="px", pointsize=30)
ggplot(done_m, aes(x=date, y=points, fill=factor(category))) +
  geom_bar(stat="identity") +
  scale_fill_manual(values=getPalette(colorCount), name="Category") +
  theme_fivethirtynine() +
  theme(axis.title.x=element_blank()) +
  theme(legend.direction='vertical', axis.title.x=element_blank()) +
  labs(title=sprintf("%s Velocity by monthly points", args$scope_title), y="Points", x="Month", aesthetic="Category")
dev.off()

png(filename = sprintf("~/html/%s_done_m_count.png", args$scope_prefix), width=2000, height=1125, units="px", pointsize=30)
ggplot(done_m, aes(x=date, y=count, fill=factor(category))) +
  geom_bar(stat="identity") +
  scale_fill_manual(values=getPalette(colorCount), name="Category") +
  theme_fivethirtynine() +
  theme(legend.direction='vertical', axis.title.x=element_blank()) +
  labs(title=sprintf("%s Velocity by monthly count", args$scope_title), y="Count", x="Month", aesthetic="Category")
dev.off()

done_q <- read.csv(sprintf("/tmp/%s/recently_closed_quarter.csv", args$scope_prefix))
done_q$date <- as.Date(done_q$date, "%Y-%m-%d")
done_q$category <- paste(sprintf("%02d",done_q$sort_order), strtrim(done_q$category, 35))
done_q$category <- factor(done_q$category, levels=rev(done_q$category[order(done_q$sort_order)]))

colorCount = length(unique(done_q$category))
getPalette = colorRampPalette(brewer.pal(9, "YlGn"))

png(filename = sprintf("~/html/%s_done_q_points.png", args$scope_prefix), width=2000, height=1125, units="px", pointsize=30)
ggplot(done_q, aes(x=date, y=points, fill=factor(category))) +
  geom_bar(stat="identity") +
  scale_fill_manual(values=getPalette(colorCount), name="Category") +
  theme_fivethirtynine() +
  theme(axis.title.x=element_blank()) +
  theme(legend.direction='vertical', axis.title.x=element_blank()) +
  labs(title=sprintf("%s Velocity by quarterly points", args$scope_title), y="Points", x="Month", aesthetic="Category")
dev.off()

png(filename = sprintf("~/html/%s_done_q_count.png", args$scope_prefix), width=2000, height=1125, units="px", pointsize=30)
ggplot(done_q, aes(x=date, y=count, fill=factor(category))) +
  geom_bar(stat="identity") +
  scale_fill_manual(values=getPalette(colorCount), name="Category") +
  theme_fivethirtynine() +
  theme(legend.direction='vertical', axis.title.x=element_blank()) +
  labs(title=sprintf("%s Velocity by quarterly count", args$scope_title), y="Count", x="Month", aesthetic="Category")
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

options(warn = oldw)
