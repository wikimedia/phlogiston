## Convert a historical transaction file from Phab into a burnup report

## library(reshape2)
library(ggplot2)
library(scales)
library(RColorBrewer)
## library(grid)

######################################################################
## Backlog
######################################################################

backlog <- read.csv("/tmp/dis_backlog.csv")
backlog$date <- as.Date(backlog$date, "%Y-%m-%d")
## manually set ordering of data

## backlog$category2 <- factor(backlog$category, levels = c("General Backlog", "TR4: Link editor tweaks", "TR3: Language support", "TR2: Mobile MVP", "TR1: Releases", "VisualEditor 2014/15 Q4 blockers", "VisualEditor 2014/15 Q3 blockers", "TR0: Interrupt", "Miscategorized"))
backlog_output=png(filename = "~/html/dis_backlog_burnup.png", width=2000, height=1125, units="px", pointsize=30)

burnup <- read.csv("/tmp/dis_burnup.csv")
burnup$date <- as.Date(burnup$date, "%Y-%m-%d")
##burnup$category2 <- 0 ## dummy colum so it fits on the same ggplot

ggplot(backlog) +
  labs(title="Discovery backlog", y="Story Point Total") +
  theme(text = element_text(size=30), legend.title=element_blank())+
  geom_area(position='stack', aes(x = date, y = points, group=category, fill=category, order=-as.numeric(category))) +
  scale_x_date(breaks="1 month", label=date_format("%Y-%b"), limits = as.Date(c('2014-12-01', NA))) +
  geom_line(data=burnup, aes(x=date, y=points), size=2)
dev.off()


## ######################################################################
## ## Maintenance Fraction
## ######################################################################

## dis_maint_frac <- read.csv("/tmp/dis_maintenance_fraction.csv")
## dis_maint_frac$date <- as.Date(dis_maint_frac$date, "%Y-%m-%d")

## status_output <- png(filename = "~/html/dis_maint_frac.png", width=2000, height=1125, units="px", pointsize=30)
  
## ggplot(dis_maint_frac, aes(date, maint_frac)) +
##   labs(title="VE Maintenance Fraction", y="Fraction of completed work that is maintenance") +
##   geom_bar(stat="identity") +
##   theme(text = element_text(size=30)) +
##   scale_y_continuous(labels=percent, limits=c(0,1))
##   dev.off()

######################################################################
## Velocity
######################################################################

velocity <- read.csv("/tmp/dis_velocity.csv")
velocity$date <- as.Date(velocity$date, "%Y-%m-%d")

velocity_output <- png(filename = "~/html/dis_velocity.png", width=2000, height=1125, units="px", pointsize=30)

ggplot(velocity, aes(date, velocity)) +
  labs(title="Velocity per week", y="Story Points") +
  geom_bar(stat="identity") +
  theme(text = element_text(size=30))
dev.off()

######################################################################
## Velocity vs backlog
######################################################################

net_growth <- read.csv("/tmp/dis_net_growth.csv")
net_growth$date <- as.Date(net_growth$date, "%Y-%m-%d")

net_growth_output <- png(filename = "~/html/dis_net_growth.png", width=2000, height=1125, units="px", pointsize=30)

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

minmax <- c("2015-08-01","2016-04-01")

line45 <- data.frame( x = c(0,1), y=c(0,1))
##line45$x <- as.Date(line45$x, format="Y%-%m-%d")
##line45$y <- as.Date(line45$y, format="Y%-%m-%d")

forecast <- data.frame(case, foredate, date)
forecast$foredate <- as.Date(forecast$foredate, format = "%Y-%m-%d")
forecast$date <- as.Date(forecast$date, format = "%Y-%m-%d")

forecast_output <- png(filename = "~/html/dis_forecast.png", width=2000, height=2000, units="px", pointsize=30)

ggplot(forecast, aes(x=foredate, y=date, group=case)) +
  geom_line(shape=1) +
  labs(title="VE Forecasting History (Tranche 1)", x="Now", y="Forecast Completion") +
  scale_x_date(limits = c(as.Date("2015-08-01"), as.Date("2016-04-01"))) +
  scale_y_date(limits = c(as.Date("2015-08-01"), as.Date("2016-04-01"))) +
  theme(text = element_text(size=30))  + 
  geom_abline(intercept = 0, slope=1, color="darkgray")
dev.off()


## Disabled pending future code cleanup in the SQL
######################################################################
## Lead Time
######################################################################

## leadtime <- read.csv("/tmp/dis_leadtime.csv")
## leadtime$week <- as.Date(leadtime$week, "%Y-%m-%d")
## leadtime_output <- png(filename = "~/html/dis_leadtime.png", width=2000, height=1125, units="px", pointsize=30)
## ggplot(leadtime, aes(x=week, y=points, fill=leadtime)) +
##   labs(title="VE Lead Time for resolved tasks", y="Story Point Total") +
##   geom_bar(stat="identity")
## dev.off()

## age_of_resolved <- read.csv("/tmp/dis_age_of_resolved.csv")
## age_of_resolved$week <- as.Date(age_of_resolved$week, "%Y-%m-%d")
## age_of_resolved_output <- png(filename = "~/html/dis_age_of_resolved.png", width=2000, height=1125, units="px", pointsize=30)
## ggplot(age_of_resolved, aes(x=week, y=sumpoints, fill=factor(points))) +
##   labs(title="VE Age of Resolved (by points)", y="Story Point Total") +
##   theme(text = element_text(size=30)) +
##   geom_bar(stat="identity")
## dev.off()

## age_of_resolved_count <- read.csv("/tmp/dis_age_of_resolved_count.csv")
## age_of_resolved_count$week <- as.Date(age_of_resolved_count$week, "%Y-%m-%d")
## age_of_resolved_count_output <- png(filename = "~/html/dis_age_of_resolved_count.png", width=2000, height=1125, units="px", pointsize=30)
## ggplot(age_of_resolved_count, aes(x=week, y=count, fill=factor(points))) +
##   labs(title="VE Age of Resolved (by count)", y="Count") +
##   theme(text = element_text(size=30)) +
##   geom_bar(stat="identity")
## dev.off()

## age_of_resolved <- read.csv("/tmp/dis_age_of_resolved.csv")
## age_of_resolved$week <- as.Date(age_of_resolved$week, "%Y-%m-%d")
## age_of_resolved_output <- png(filename = "~/html/dis_age_of_resolved.png", width=2000, height=1125, units="px", pointsize=30)
## ggplot(age_of_resolved, aes(x=week, y=sumpoints, fill=factor(points))) +
##   labs(title="VE Age of Resolved (by points)", y="Story Point Total") +
##   theme(text = element_text(size=30)) +
##   geom_bar(stat="identity") +
##   scale_fill_discrete(name="Size of Story in Points")
## dev.off()

## age_of_resolved_count <- read.csv("/tmp/dis_age_of_resolved_count.csv")
## age_of_resolved_count$week <- as.Date(age_of_resolved_count$week, "%Y-%m-%d")
## age_of_resolved_count_output <- png(filename = "~/html/dis_age_of_resolved_count.png", width=2000, height=1125, units="px", pointsize=30)
## ggplot(age_of_resolved_count, aes(x=week, y=count, fill=factor(points))) +
##   labs(title="VE Age of Resolved (by count)", y="Count") +
##   theme(text = element_text(size=30)) +
##   geom_bar(stat="identity") +
##   scale_fill_discrete(name="Size of Story in Points")
## dev.off()

## backlogage <- read.csv("/tmp/dis_age_of_backlog_specific.csv")
## backlogage$week <- as.Date(backlogage$week, "%Y-%m-%d")
## backlogage_output <- png(filename = "~/html/dis_age_of_backlog_specific.png", width=2000, height=1125, units="px", pointsize=30)
## ggplot(backlogage, aes(x=week, y=points, fill=age)) +
##   labs(title="Age of VE backlog (open tasks), excluding General Backlog", y="Story Point Total") +
##   theme(text = element_text(size=30)) +
##   geom_bar(stat="identity") +
##   scale_fill_continuous(name="Age in months")
## dev.off()
