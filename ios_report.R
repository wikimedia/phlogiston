## Convert a historical transaction file from Phab into a burnup report

library(reshape2)
library(ggplot2)
library(scales)
library(grid)
library(RColorBrewer)

######################################################################
## Analytics Status
######################################################################

ios_status=read.csv("/tmp/ios_status.csv")
ios_status$date <- as.Date(ios_status$date, "%Y-%m-%d")

ve_status_output=png(filename = "/tmp/ios-backlog-status.png", width=2000, height=1125, units="px", pointsize=30)
    
ggplot(ios_status) +
    labs(title="Disposition of the iOS backlog", y="Story Point Total") +
    theme(text = element_text(size=30), legend.title=element_blank())+
    geom_area(position='stack', aes(x = date, y = points, group=status, fill=status, order=-as.numeric(status))) +
    scale_x_date(breaks="1 month", label=date_format("%Y-%b"), limits = as.Date(c('2014-12-01', NA))) +
    scale_y_continuous(limits=c(0, 2000))
dev.off()

######################################################################
## Backlog
######################################################################

backlog=read.csv("/tmp/ios_backlog.csv")
backlog$date <- as.Date(backlog$date, "%Y-%m-%d")
## manually set ordering of data

burnup=read.csv("/tmp/ios_burnup.csv")
burnup$date <- as.Date(burnup$date, "%Y-%m-%d")
burnup_output=png(filename = "/tmp/ios-backlog_burnup.png", width=2000, height=1125, units="px", pointsize=30)
    
ggplot(backlog) +
    labs(title="iOS backlog", y="Story Point Total") +
    theme(text = element_text(size=30), legend.title=element_blank())+
    geom_area(position='stack', aes(x = date, y = points, group=project, fill=project, order=-as.numeric(project))) +
    scale_x_date(breaks="1 month", label=date_format("%Y-%b"), limits = as.Date(c('2015-01-01', NA))) +
    scale_y_continuous(limits=c(0, 2000)) +
        geom_line(data=burnup, aes(x=date, y=points), size=2)
dev.off()


######################################################################
## Velocity
######################################################################

velocity=read.csv("/tmp/ios_velocity.csv")
velocity$week <- as.Date(velocity$week, "%Y-%m-%d")

velocity_output=png(filename = "/tmp/ios-velocity.png", width=2000, height=1125, units="px", pointsize=30)

ggplot(velocity, aes(week, velocity)) +
    labs(title="iOS Velocity per week", y="Story Points") +
    geom_bar(stat="identity")
dev.off()

######################################################################
## Lead Time
######################################################################

leadtime=read.csv("/tmp/ios_leadtime.csv")
leadtime$week <- as.Date(leadtime$week, "%Y-%m-%d")
leadtime_output=png(filename = "/tmp/ios-leadtime.png", width=2000, height=1125, units="px", pointsize=30)
ggplot(leadtime, aes(x=week, y=points, fill=leadtime)) +
    labs(title="iOS Lead Time for resolved tasks", y="Story Point Total") +
    geom_bar(stat="identity")
dev.off()

histodate=read.csv("/tmp/ios_histopoints.csv")
histodate$week <- as.Date(histodate$week, "%Y-%m-%d")
histodate_output=png(filename = "/tmp/ios-histodate.png", width=2000, height=1125, units="px", pointsize=30)
ggplot(histodate, aes(x=week, y=count, fill=factor(points))) +
    labs(title="iOS Age of backlog", y="Story Point Total") +
    geom_bar(stat="identity")
dev.off()
