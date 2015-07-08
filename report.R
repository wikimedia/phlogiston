## Convert a historical transaction file from Phab into a burnup report

library(dplyr)
library(reshape2)
library(ggplot2)
library(scales)

backlog=read.csv("/tmp/VE_backlog.csv")

## Backlog

## convert string to date
backlog$date <- as.Date(backlog$date, "%Y-%m-%d")
## manually set ordering of data
backlog$project2 <- factor(backlog$project, levels = c("VisualEditor","VisualEditor 2015/16 Q1 blockers","VisualEditor 2014/15 Q4 blockers","VisualEditor 2014/15 Q3 blockers","VisualEditor Interrupt"))

burnup=read.csv("/tmp/VE_burnup.csv")
burnup$date <- as.Date(burnup$date, "%Y-%m-%d")
burnup$project2 <- 0 ## dummy colum so it fits on the same ggplot
burnup_output=png(filename = "VE-backlog_burnup.png", width=2000, height=1400, units="px", pointsize=30)
    
ggplot(backlog) +
    labs(title="VE backlog", y="Story Point Total") +
    theme(text = element_text(size=30), legend.title=element_blank()) +
    geom_area(position='stack', aes(x = date, y = point_total, group=project2, fill=project2, order=-as.numeric(project2))) +
    scale_x_date(breaks="1 month", label=date_format("%Y-%b"), limits = as.Date(c('2014-12-01', '2015-06-30'))) +
    scale_y_continuous(limits=c(0, 60000)) +
    geom_point(data=burnup, aes(x=date, y=points))
dev.off()

burnup_crop_output=png(filename = "VE-backlog_burnup_crop.png", width=2000, height=1400, units="px", pointsize=30)
    
ggplot(backlog) +
    labs(title="VE backlog (Zoomed)", y="Story Point Total") +
    theme(text = element_text(size=30), legend.title=element_blank()) +
    geom_area(position='stack', aes(x = date, y = point_total, group=project2, fill=project2, order=-as.numeric(project2))) +
    scale_x_date(breaks="1 month", label=date_format("%Y-%b"), limits = as.Date(c('2014-12-01', '2015-06-30'))) +
    scale_y_continuous(limits=c(0, 10000)) +
    geom_point(data=burnup, aes(x=date, y=points))
dev.off()

vestatus=read.csv("/tmp/VE_status.csv")
vestatus$date <- as.Date(vestatus$date, "%Y-%m-%d")

status_output=png(filename = "VE-status.png", width=2000, height=1400, units="px", pointsize=30)
    
ggplot(vestatus) +
    labs(title="Burnup vs resolved Interrupt", y="Story Point Total") +
    theme(text = element_text(size=30), legend.title=element_blank()) +
    geom_area(position='stack', aes(x = date, y = point_total, group=status, fill=status, order=as.numeric(status))) +
    scale_x_date(breaks="1 month", label=date_format("%Y-%b"), limits = as.Date(c('2014-12-01', '2015-06-30'))) +
    scale_y_continuous(limits=c(0, 60000)) +
    geom_point(data=burnup, aes(x=date, y=points))
dev.off()

velocity=read.csv("/tmp/VE_velocity.csv")
velocity$week <- as.Date(velocity$week, "%Y-%m-%d")

velocity_output=png(filename = "VE-velocity.png", width=1000, height=700, units="px", pointsize=30)

ggplot(velocity, aes(week, velocity)) +
    labs(title="Velocity per week", y="Story Points") +
        geom_bar(stat="identity")

dev.off()

net_growth=read.csv("/tmp/VE_net_growth.csv")
net_growth$date <- as.Date(net_growth$date, "%Y-%m-%d")

net_growth_output=png(filename = "VE-net_growth.png", width=1000, height=700, units="px", pointsize=30)

ggplot(net_growth, aes(date, growth)) +
    labs(title="Net change in open backlog", y="Story Points") +
        geom_bar(stat="identity") +
            scale_y_log10(limits=c(-100, 10000))

dev.off()

##histogram_output=png(filename = "VE-histogram.png", width=2000, height=1400, units="px", pointsize=30)

##point_hist=read.csv("/tmp/histogram.csv");
##point_hist_wide <- dcast(point <- hist, points + project ~ category, value.var="count")


## ggplot(phab_summ, aes(x = Date, y = point_total, group=point_total, fill=Project)) + geom_area(position='stack')

## phab_summ_t = dcast(phab_summ, Date ~ Project)

## velocity = group_by(phab_data, Date, Status)

## velocity = summarize(velocity, point_total = sum(Points))

## velocityT = dcast(velocity, Date ~ Status)

## write.csv(VelocityT, file="velocity.csv")
## write.csv(phab_summ_t, file="backlog.csv")


