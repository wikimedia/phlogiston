## Convert a historical transaction file from Phab into a burnup report

## library(reshape2)
library(ggplot2)
library(scales)
library(RColorBrewer)
## library(grid)

######################################################################
## Backlog
######################################################################

backlog <- read.csv("/tmp/ve_backlog.csv")
backlog$date <- as.Date(backlog$date, "%Y-%m-%d")
## manually set ordering of data
colors = brewer.pal(9, "PuOr")

backlog$category2 <- factor(backlog$category, levels = c("General Backlog", "TR4: Link editor tweaks", "TR3: Language support", "TR2: Mobile MVP", "TR1: Releases", "VisualEditor 2014/15 Q4 blockers", "VisualEditor 2014/15 Q3 blockers", "TR0: Interrupt", "Miscategorized"))
backlog_output=png(filename = "~/html/ve-backlog_burnup.png", width=2000, height=1125, units="px", pointsize=30)

burnup <- read.csv("/tmp/ve_burnup.csv")
burnup$date <- as.Date(burnup$date, "%Y-%m-%d")
burnup$category2 <- 0 ## dummy colum so it fits on the same ggplot

ggplot(backlog) +
  labs(title="VE backlog", y="Story Point Total") +
  theme(text = element_text(size=30), legend.title=element_blank())+
  geom_area(position='stack', aes(x = date, y = points, group=category2, fill=category2, order=-as.numeric(category2))) +
  scale_fill_manual(values = colors) +
  scale_x_date(breaks="1 month", label=date_format("%Y-%b"), limits = as.Date(c('2014-12-01', NA))) +
  geom_line(data=burnup, aes(x=date, y=points), size=2)
dev.off()

######################################################################
## Zoomed backlog

backlog_zoomed <- read.csv("/tmp/ve_backlog_zoomed.csv")
backlog_zoomed$date <- as.Date(backlog_zoomed$date, "%Y-%m-%d")
## manually set ordering of data
backlog_zoomed$category2 <- factor(backlog_zoomed$category, levels = c("TR4: Link editor tweaks", "TR3: Language support", "TR2: Mobile MVP", "TR1: Releases", "VisualEditor 2014/15 Q4 blockers", "VisualEditor 2014/15 Q3 blockers"))
burnup_zoom_output=png(filename = "~/html/ve-backlog_burnup_zoom.png", width=2000, height=1125, units="px", pointsize=30)

burnup_zoomed <- read.csv("/tmp/ve_burnup_zoomed.csv")
burnup_zoomed$date <- as.Date(burnup_zoomed$date, "%Y-%m-%d")
burnup_zoomed$category2 <- 0 ## dummy colum so it fits on the same ggplot

ggplot(backlog_zoomed) +
  labs(title="VE Planned backlog (excludes Maintenance and General Backlog)", y="Story Point Total") +
  theme(text = element_text(size=30), legend.title=element_blank()) +
  geom_area(position='stack', aes(x = date, y = points, group=category2, fill=category2, order=-as.numeric(category2))) +
  scale_x_date(breaks="1 month", label=date_format("%Y-%b"), limits = as.Date(c('2015-02-01', NA))) +
  scale_fill_manual(values = colors) +
  geom_line(data=burnup_zoomed, aes(x=date, y=points), size=2)
dev.off()

######################################################################
## Tranches
## Tranches 1 through 4 are Y-scaled for consistency across different charts

burnup_cat <- read.csv("/tmp/ve_burnup_categories.csv")
burnup_cat$date <- as.Date(burnup_cat$date, "%Y-%m-%d")

## TR0

burnup_output <- png(filename = "~/html/ve-tranch0_burnup.png", width=2000, height=1125, units="px", pointsize=30)
par(las=3) ## vertical labels
ggplot(backlog[backlog$category=='TR0: Interrupt',]) + 
   labs(title="VE Interruptions (Tranche 0)", y="Story Point Total") +
   theme(text = element_text(size=30), legend.title=element_blank())+
   geom_area(position='stack', aes(x = date, y = points, ymin=0), fill="#8073AC") +
   scale_x_date(breaks="1 month", label=date_format("%Y-%b-%d"), limits = as.Date(c('2015-06-18', NA))) +
   geom_line(data=burnup_cat[burnup_cat$category=='TR0: Interrupt',], aes(x=date, y=points), size=2)
dev.off()

##> colors
##[1] "#B35806"Gen "#E08214"TR4 "#FDB863"TR3 "#FEE0B6"TR2 "#F7F7F7"TR1 "#D8DAEB"Q4 "#B2ABD2"Q3
##[8] "#8073AC" "#542788"

## TR1

burnup_output <- png(filename = "~/html/ve-tranch1_burnup.png", width=2000, height=1125, units="px", pointsize=30)
ggplot(backlog[backlog$category=='TR1: Releases',]) + 
   labs(title="TR1: Releases", y="Story Point Total") +
   theme(text = element_text(size=30), legend.title=element_blank())+
   geom_area(position='stack', aes(x = date, y = points, ymin=0), fill="#F7F7F7") +
   scale_x_date(breaks="1 month", label=date_format("%Y-%b-%d"), limits = as.Date(c('2015-06-18', NA))) +
   scale_y_continuous(limits=c(0, 1000)) +
   geom_line(data=burnup_cat[burnup_cat$category=='TR1: Releases',], aes(x=date, y=points), size=2)
dev.off()

## TR2

burnup_output <- png(filename = "~/html/ve-tranch2_burnup.png", width=2000, height=1125, units="px", pointsize=30)
ggplot(backlog[backlog$category=='TR2: Mobile MVP',]) + 
   labs(title="TR2: Mobile MVP", y="Story Point Total") +
   theme(text = element_text(size=30), legend.title=element_blank())+
   geom_area(position='stack', aes(x = date, y = points, ymin=0), fill="#FEE0B6") +
   scale_x_date(breaks="1 month", label=date_format("%Y-%b-%d"), limits = as.Date(c('2015-06-18', NA))) +
   scale_y_continuous(limits=c(0, 1000)) +
   geom_line(data=burnup_cat[burnup_cat$category=='TR2: Mobile MVP',], aes(x=date, y=points), size=2)
dev.off()

## TR3

burnup_output <- png(filename = "~/html/ve-tranch3_burnup.png", width=2000, height=1125, units="px", pointsize=30)
ggplot(backlog[backlog$category=='TR3: Language support',]) + 
   labs(title="TR3: Language support", y="Story Point Total") +
   theme(text = element_text(size=30), legend.title=element_blank())+
   geom_area(position='stack', aes(x = date, y = points, ymin=0), fill="#FDB863") +
   scale_x_date(breaks="1 month", label=date_format("%Y-%b-%d"), limits = as.Date(c('2015-06-18', NA))) +
   scale_y_continuous(limits=c(0, 1000)) +
   geom_line(data=burnup_cat[burnup_cat$category=='TR3: Language support',], aes(x=date, y=points), size=2)
dev.off()

## TR4

burnup_output <- png(filename = "~/html/ve-tranch4_burnup.png", width=2000, height=1125, units="px", pointsize=30)
ggplot(backlog[backlog$category=='TR4: Link editor tweaks',]) + 
   labs(title="TR4: Link editor tweaks", y="Story Point Total") +
   theme(text = element_text(size=30), legend.title=element_blank())+
   geom_area(position='stack', aes(x = date, y = points, ymin=0), fill="#E08214") +
   scale_x_date(breaks="1 month", label=date_format("%Y-%b-%d"), limits = as.Date(c('2015-06-18', NA))) +
   scale_y_continuous(limits=c(0, 1000)) +
   geom_line(data=burnup_cat[burnup_cat$category=='TR4: Link editor tweaks',], aes(x=date, y=points), size=2)
dev.off()

######################################################################
## Maintenance Fraction
######################################################################

ve_maint_frac <- read.csv("/tmp/ve_maintenance_fraction.csv")
ve_maint_frac$date <- as.Date(ve_maint_frac$date, "%Y-%m-%d")

status_output <- png(filename = "~/html/ve-maint_frac.png", width=2000, height=1125, units="px", pointsize=30)
  
ggplot(ve_maint_frac, aes(date, maint_frac)) +
  labs(title="VE Maintenance Fraction", y="Fraction of completed work that is maintenance") +
  geom_bar(stat="identity") +
  theme(text = element_text(size=30)) +
  scale_y_continuous(labels=percent, limits=c(0,1))
  dev.off()

######################################################################
## Velocity
######################################################################

velocity <- read.csv("/tmp/ve_velocity.csv")
velocity$date <- as.Date(velocity$date, "%Y-%m-%d")

velocity_output <- png(filename = "~/html/ve-velocity.png", width=2000, height=1125, units="px", pointsize=30)

ggplot(velocity, aes(date, velocity)) +
  labs(title="Velocity per week", y="Story Points") +
  geom_bar(stat="identity") +
  theme(text = element_text(size=30))
dev.off()

######################################################################
## Velocity vs backlog
######################################################################

net_growth <- read.csv("/tmp/ve_net_growth.csv")
net_growth$date <- as.Date(net_growth$date, "%Y-%m-%d")

net_growth_output <- png(filename = "~/html/ve-net_growth.png", width=2000, height=1125, units="px", pointsize=30)

ggplot(net_growth, aes(date, points)) +
  labs(title="Net change in open backlog", y="Story Points") +
  geom_bar(stat="identity") +
  theme(text = element_text(size=30))
dev.off()

######################################################################
## Forecast
######################################################################
## For now, plot manually collected data.

case <- c("Pess","Nom","Opt","Pess","Nom","Opt")
foredate <- c("2015-08-12","2015-08-12","2015-08-12","2015-09-21","2015-09-21","2015-09-21")
date <- c("2016-03-21","2015-10-15","2015-09-25","2015-11-27","2015-10-15","2015-10-01")

forecast <- data.frame(case, foredate, date)
forecast$foredate <- as.Date(forecast$foredate, format = "%Y-%m-%d")
forecast$date <- as.Date(forecast$date, format = "%Y-%m-%d")

forecast_output <- png(filename = "~/html/ve-forecast.png", width=2000, height=1125, units="px", pointsize=30)

ggplot(forecast, aes(x=foredate, y=date, group=case)) +
  geom_line(shape=1) +
  scale_x_date(limits = c(as.Date("2015-08-01"), as.Date("2016-04-01"))) +
  scale_y_date(limits = c(as.Date("2015-08-01"), as.Date("2016-04-01"))) +
  theme(text = element_text(size=30)) 
dev.off()

## Disabled pending future code cleanup in the SQL
######################################################################
## Lead Time
######################################################################

## leadtime <- read.csv("/tmp/ve_leadtime.csv")
## leadtime$week <- as.Date(leadtime$week, "%Y-%m-%d")
## leadtime_output <- png(filename = "~/html/ve-leadtime.png", width=2000, height=1125, units="px", pointsize=30)
## ggplot(leadtime, aes(x=week, y=points, fill=leadtime)) +
##   labs(title="VE Lead Time for resolved tasks", y="Story Point Total") +
##   geom_bar(stat="identity")
## dev.off()

## age_of_resolved <- read.csv("/tmp/ve_age_of_resolved.csv")
## age_of_resolved$week <- as.Date(age_of_resolved$week, "%Y-%m-%d")
## age_of_resolved_output <- png(filename = "~/html/ve-age_of_resolved.png", width=2000, height=1125, units="px", pointsize=30)
## ggplot(age_of_resolved, aes(x=week, y=sumpoints, fill=factor(points))) +
##   labs(title="VE Age of Resolved (by points)", y="Story Point Total") +
##   theme(text = element_text(size=30)) +
##   geom_bar(stat="identity")
## dev.off()

## age_of_resolved_count <- read.csv("/tmp/ve_age_of_resolved_count.csv")
## age_of_resolved_count$week <- as.Date(age_of_resolved_count$week, "%Y-%m-%d")
## age_of_resolved_count_output <- png(filename = "~/html/ve-age_of_resolved_count.png", width=2000, height=1125, units="px", pointsize=30)
## ggplot(age_of_resolved_count, aes(x=week, y=count, fill=factor(points))) +
##   labs(title="VE Age of Resolved (by count)", y="Count") +
##   theme(text = element_text(size=30)) +
##   geom_bar(stat="identity")
## dev.off()

## age_of_resolved <- read.csv("/tmp/ve_age_of_resolved.csv")
## age_of_resolved$week <- as.Date(age_of_resolved$week, "%Y-%m-%d")
## age_of_resolved_output <- png(filename = "~/html/ve-age_of_resolved.png", width=2000, height=1125, units="px", pointsize=30)
## ggplot(age_of_resolved, aes(x=week, y=sumpoints, fill=factor(points))) +
##   labs(title="VE Age of Resolved (by points)", y="Story Point Total") +
##   theme(text = element_text(size=30)) +
##   geom_bar(stat="identity") +
##   scale_fill_discrete(name="Size of Story in Points")
## dev.off()

## age_of_resolved_count <- read.csv("/tmp/ve_age_of_resolved_count.csv")
## age_of_resolved_count$week <- as.Date(age_of_resolved_count$week, "%Y-%m-%d")
## age_of_resolved_count_output <- png(filename = "~/html/ve-age_of_resolved_count.png", width=2000, height=1125, units="px", pointsize=30)
## ggplot(age_of_resolved_count, aes(x=week, y=count, fill=factor(points))) +
##   labs(title="VE Age of Resolved (by count)", y="Count") +
##   theme(text = element_text(size=30)) +
##   geom_bar(stat="identity") +
##   scale_fill_discrete(name="Size of Story in Points")
## dev.off()

## backlogage <- read.csv("/tmp/ve_age_of_backlog_specific.csv")
## backlogage$week <- as.Date(backlogage$week, "%Y-%m-%d")
## backlogage_output <- png(filename = "~/html/ve-age_of_backlog_specific.png", width=2000, height=1125, units="px", pointsize=30)
## ggplot(backlogage, aes(x=week, y=points, fill=age)) +
##   labs(title="Age of VE backlog (open tasks), excluding General Backlog", y="Story Point Total") +
##   theme(text = element_text(size=30)) +
##   geom_bar(stat="identity") +
##   scale_fill_continuous(name="Age in months")
## dev.off()
