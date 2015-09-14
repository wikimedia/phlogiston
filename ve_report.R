## Convert a historical transaction file from Phab into a burnup report

## library(reshape2)
library(ggplot2)
library(scales)
## library(grid)

######################################################################
## Backlog
######################################################################

backlog <- read.csv("/tmp/ve_backlog.csv")
backlog$date <- as.Date(backlog$date, "%Y-%m-%d")
## manually set ordering of data
backlog$category2 <- factor(backlog$category, levels = c("General Backlog", "TR4: Link editor tweaks", "TR3: Language support", "TR2: Mobile MVP", "TR1: Releases", "VisualEditor 2014/15 Q4 blockers", "VisualEditor 2014/15 Q3 blockers", "TR0: Interrupt", "Miscategorized"))
backlog_output=png(filename = "~/html/ve-backlog_burnup.png", width=2000, height=1125, units="px", pointsize=30)

burnup <- read.csv("/tmp/ve_burnup.csv")
burnup$date <- as.Date(burnup$date, "%Y-%m-%d")
burnup$category2 <- 0 ## dummy colum so it fits on the same ggplot

ggplot(backlog) +
  labs(title="VE backlog", y="Story Point Total") +
  theme(text = element_text(size=30), legend.title=element_blank())+
  geom_area(position='stack', aes(x = date, y = points, group=category2, fill=category2, order=-as.numeric(category2))) +
  scale_x_date(breaks="1 month", label=date_format("%Y-%b"), limits = as.Date(c('2014-12-01', NA))) +
  scale_y_continuous(limits=c(0, 100000)) +
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
  labs(title="VE backlog (zoomed; excludes Maintenance and General Backlog)", y="Story Point Total") +
  theme(text = element_text(size=30), legend.title=element_blank()) +
  geom_area(position='stack', aes(x = date, y = points, group=category2, fill=category2, order=-as.numeric(category2))) +
  scale_x_date(breaks="1 month", label=date_format("%Y-%b"), limits = as.Date(c('2015-02-01', NA))) +
  scale_y_continuous(limits=c(0, 10000)) +
  geom_line(data=burnup, aes(x=date, y=points), size=2)
dev.off()

## Excluding Interrupt

backlog_no_interrupt <- read.csv("/tmp/ve_backlog_zoomed.csv")
backlog_no_interrupt$date <- as.Date(backlog_no_interrupt$date, "%Y-%m-%d")
## manually set ordering of data
backlog_no_interrupt$category2 <- factor(backlog_no_interrupt$category, levels = c("General Backlog_No_Interrupt", "TR4: Link editor tweaks", "TR3: Language support", "TR2: Mobile MVP", "TR1: Releases", "VisualEditor 2014/15 Q4 blockers", "VisualEditor 2014/15 Q3 blockers", "TR0: Interrupt", "Miscategorized"))
backlog_no_interrupt_output=png(filename = "~/html/ve-backlog_no_interrupt_burnup.png", width=2000, height=1125, units="px", pointsize=30)

burnup <- read.csv("/tmp/ve_burnup.csv")
burnup$date <- as.Date(burnup$date, "%Y-%m-%d")
burnup$category2 <- 0 ## dummy colum so it fits on the same ggplot

ggplot(backlog_no_interrupt) +
  labs(title="VE backlog (excluding Maintenance)", y="Story Point Total") +
  theme(text = element_text(size=30), legend.title=element_blank())+
  geom_area(position='stack', aes(x = date, y = points, group=category2, fill=category2, order=-as.numeric(category2))) +
  scale_x_date(breaks="1 month", label=date_format("%Y-%b"), limits = as.Date(c('2014-12-01', NA))) +
  scale_y_continuous(limits=c(0, 100000)) +
  geom_line(data=burnup, aes(x=date, y=points), size=2)
dev.off()

######################################################################
## TR0

## burnup_output <- png(filename = "~/html/ve-tranch0_burnup.png", width=2000, height=1125, units="px", pointsize=30)

## par(las=3) ## vertical labels
## ggplot(backlog[backlog$category=='TR0: Interrupt',]) + 
##   labs(title="VE Interruptions (Tranche 0)", y="Story Point Total") +
##   theme(text = element_text(size=30), legend.title=element_blank())+
##   geom_area(position='stack', aes(x = date, y = points, ymin=0), fill="lightblue") +
##   scale_x_date(breaks="1 week", label=date_format("%Y-%b-%d"), limits = as.Date(c('2015-06-18', NA))) +
##   scale_y_continuous(limits=c(0, 800)) +
##   geom_line(data=burnup[burnup$category=='TR0: Interrupt'], aes(x=date, y=points), size=2)
## dev.off()

## ######################################################################
## ## TR1

## tr_burnup <- read.csv("/tmp/ve_TR1.csv")
## tr_burnup$date <- as.Date(tr_burnup$date, "%Y-%m-%d")
## burnup_output <- png(filename = "~/html/ve-tranch1_burnup.png", width=2000, height=1125, units="px", pointsize=30)
  
## ggplot(tr_burnup) +
##   labs(title="VE Tranch 1 backlog", y="Story Point Total") +
##   theme(text = element_text(size=30), legend.title=element_blank())+
##   geom_area(position='stack', aes(x = date, y = points, group=status, fill=status, order=-as.numeric(status))) +
##   scale_x_date(breaks="1 week", label=date_format("%Y-%b-%d"), limits = as.Date(c('2015-06-18', NA))) +
##   scale_y_continuous(limits=c(0, 800)) 
## dev.off()

## ######################################################################
## ## TR2

## tr_burnup <- read.csv("/tmp/ve_TR2.csv")
## tr_burnup$date <- as.Date(tr_burnup$date, "%Y-%m-%d")
## burnup_output <- png(filename = "~/html/ve-tranch2_burnup.png", width=2000, height=1125, units="px", pointsize=30)
  
## ggplot(tr_burnup) +
##   labs(title="VE Tranch 2 backlog", y="Story Point Total") +
##   theme(text = element_text(size=30), legend.title=element_blank())+
##   geom_area(position='stack', aes(x = date, y = points, group=status, fill=status, order=-as.numeric(status))) +
##   scale_x_date(breaks="1 week", label=date_format("%Y-%b-%d"), limits = as.Date(c('2015-06-18', NA))) +
##   scale_y_continuous(limits=c(0, 800)) 
## dev.off()

## ######################################################################
## ## TR3

## tr_burnup <- read.csv("/tmp/ve_TR3.csv")
## tr_burnup$date <- as.Date(tr_burnup$date, "%Y-%m-%d")
## burnup_output <- png(filename = "~/html/ve-tranch3_burnup.png", width=2000, height=1125, units="px", pointsize=30)
  
## ggplot(tr_burnup) +
##   labs(title="VE Tranch 3 backlog", y="Story Point Total") +
##   theme(text = element_text(size=30), legend.title=element_blank())+
##   geom_area(position='stack', aes(x = date, y = points, group=status, fill=status, order=-as.numeric(status))) +
##   scale_y_continuous(limits=c(0, 800)) 
## dev.off()

## ######################################################################
## ## TR4

## tr_burnup <- read.csv("/tmp/ve_TR4.csv")
## tr_burnup$date <- as.Date(tr_burnup$date, "%Y-%m-%d")
## burnup_output <- png(filename = "~/html/ve-tranch4_burnup.png", width=2000, height=1125, units="px", pointsize=30)
  
## ggplot(tr_burnup) +
##   labs(title="VE Tranch 4 backlog", y="Story Point Total") +
##   theme(text = element_text(size=30), legend.title=element_blank())+
##   geom_area(position='stack', aes(x = date, y = points, group=status, fill=status, order=-as.numeric(status))) +
##   scale_y_continuous(limits=c(0, 800)) 
## dev.off()

## ######################################################################
## ## TR5

## tr_burnup <- read.csv("/tmp/ve_TR5.csv")
## tr_burnup$date <- as.Date(tr_burnup$date, "%Y-%m-%d")
## burnup_output <- png(filename = "~/html/ve-tranch5_burnup.png", width=2000, height=1125, units="px", pointsize=30)
  
## ggplot(tr_burnup) +
##   labs(title="VE Tranch 5 backlog", y="Story Point Total") +
##   theme(text = element_text(size=30), legend.title=element_blank())+
##   geom_area(position='stack', aes(x = date, y = points, group=status, fill=status, order=-as.numeric(status))) +
##   scale_y_continuous(limits=c(0, 800)) 
## dev.off()

######################################################################
## Maintenance Fraction
######################################################################

ve_maint_frac <- read.csv("/tmp/ve_maintenance_fraction.csv")
ve_maint_frac$week <- as.Date(ve_maint_frac$week, "%Y-%m-%d")

status_output <- png(filename = "~/html/ve-maint_frac.png", width=2000, height=1125, units="px", pointsize=30)
  
ggplot(ve_maint_frac, aes(week, maint_frac)) +
  labs(title="VE Maintenance Fraction", y="Fraction of completed work that is maintenance") +
  geom_bar(stat="identity") +
      theme(text = element_text(size=30)) +
          scale_y_continuous(labels=percent, limits=c(0,1))
dev.off()

######################################################################
## Velocity
######################################################################

velocity <- read.csv("/tmp/ve_velocity.csv")
velocity$week <- as.Date(velocity$week, "%Y-%m-%d")

velocity_output <- png(filename = "~/html/ve-velocity.png", width=2000, height=1125, units="px", pointsize=30)

ggplot(velocity, aes(week, velocity)) +
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

ggplot() +
  labs(title="Net change in open backlog", y="Story Points") +
  theme(text = element_text(size=30), legend.title=element_blank())+
  geom_line(data = net_growth, stat="identity", aes(date, points), size=2)
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
