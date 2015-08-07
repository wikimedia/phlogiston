## Convert a historical transaction file from Phab into a burnup report

library(reshape2)
library(ggplot2)
library(scales)
library(grid)
library(RColorBrewer)

######################################################################
## Analytics Status
######################################################################

an_status=read.csv("/tmp/an_status.csv")
an_status$date <- as.Date(an_status$date, "%Y-%m-%d")

ve_status_output=png(filename = "/tmp/an-backlog-status.png", width=2000, height=1125, units="px", pointsize=30)
    
ggplot(an_status) +
    labs(title="Disposition of the Project B backlog", y="Story Point Total") +
    theme(text = element_text(size=30), legend.title=element_blank())+
    geom_area(position='stack', aes(x = date, y = points, group=status, fill=status, order=-as.numeric(status))) +
    scale_x_date(breaks="1 month", label=date_format("%Y-%b"), limits = as.Date(c('2014-12-01', NA))) +
    scale_y_continuous(limits=c(0, 2000))
dev.off()

######################################################################
## Backlog
######################################################################

backlog=read.csv("/tmp/an_backlog.csv")
backlog$date <- as.Date(backlog$date, "%Y-%m-%d")
## manually set ordering of data

burnup=read.csv("/tmp/an_burnup.csv")
burnup$date <- as.Date(burnup$date, "%Y-%m-%d")
burnup_output=png(filename = "/tmp/an-backlog_burnup.png", width=2000, height=1125, units="px", pointsize=30)
    
ggplot(backlog) +
    labs(title="Project B backlog", y="Story Point Total") +
    theme(text = element_text(size=30), legend.title=element_blank())+
    geom_area(position='stack', aes(x = date, y = points, group=project, fill=project, order=-as.numeric(project))) +
    scale_x_date(breaks="1 month", label=date_format("%Y-%b"), limits = as.Date(c('2015-01-01', NA))) +
    scale_y_continuous(limits=c(0, 2000)) +
        geom_line(data=burnup, aes(x=date, y=points), size=2)
dev.off()


######################################################################
## Velocity
######################################################################

velocity=read.csv("/tmp/an_velocity.csv")
velocity$week <- as.Date(velocity$week, "%Y-%m-%d")

velocity_output=png(filename = "/tmp/an-velocity.png", width=2000, height=1125, units="px", pointsize=30)

ggplot(velocity, aes(week, velocity)) +
    labs(title="Project B Velocity per week", y="Story Points") +
    geom_bar(stat="identity")
dev.off()

######################################################################
## Lead Time
######################################################################

leadtime=read.csv("/tmp/an_leadtime.csv")
leadtime$week <- as.Date(leadtime$week, "%Y-%m-%d")

leadtime_output=png(filename = "/tmp/an-leadtime.png", width=2000, height=1125, units="px", pointsize=30)

ggplot(leadtime, aes(x=week, y=count, fill=leadtime)) +
    geom_bar(stat="identity")

dev.off()

## ######################################################################
## ## Velocity vs backlog
## ######################################################################

## net_growth=read.csv("/tmp/an_net_growth.csv")
## net_growth$date <- as.Date(net_growth$date, "%Y-%m-%d")

## net_growth_output=png(filename = "/tmp/an-net_growth.png", width=2000, height=1125, units="px", pointsize=30)

## ggplot() +
##     labs(title="Net change in open backlog", y="Story Points") +
##     theme(text = element_text(size=30), legend.title=element_blank())+
##     geom_line(data = net_growth, stat="identity", aes(date, points), size=2)
## dev.off()

## ######################################################################
## ## Velocity vs backlog
## ######################################################################

## net_growth=read.csv("/tmp/an_net_growth.csv")
## net_growth$date <- as.Date(net_growth$date, "%Y-%m-%d")

## net_growth_output=png(filename = "/tmp/an-net_growth.png", width=2000, height=1125, units="px", pointsize=30)

## ggplot() +
##     labs(title="Net change in open backlog", y="Story Points") +
##     theme(text = element_text(size=30), legend.title=element_blank())+
##     geom_line(data = net_growth, stat="identity", aes(date, points), size=2)
## dev.off()

## ##histogram_output=png(filename = "/tmp/an-histogram.png", width=2000, height=1125, units="px", pointsize=30)
## ##point_hist=read.csv("/tmp/histogram.csv");
## ##point_hist_wide <- dcast(point <- hist, points + project ~ category, value.var="count")
## ## ggplot(phab_summ, aes(x = Date, y = points, group=points, fill=Project)) + geom_area(position='stack')
## ## phab_summ_t = dcast(phab_summ, Date ~ Project)
## ## velocity = group_by(phab_data, Date, Status)
## ## velocity = summarize(velocity, points = sum(Points))
## ## velocityT = dcast(velocity, Date ~ Status)
## ## write.csv(VelocityT, file="velocity.csv")
## ## write.csv(phab_summ_t, file="backlog.csv")

## ######################################################################
## ## Tranche Backlog
## ######################################################################

## tranche_backlog=read.csv("/tmp/an_tranche_backlog.csv")

## ## Backlog

## tranche_backlog$date <- as.Date(tranche_backlog$date, "%Y-%m-%d")
## tranche_backlog$project2 <- factor(tranche_backlog$project, levels = c("VisualEditor TR0: Interrupt", "VisualEditor TR1: Releases", "VisualEditor TR2: Mobile MVP", "VisualEditor TR3: Language support", "VisualEditor TR4: Link editor tweaks"))

## burnup_tranche_output=png(filename = "/tmp/an-tranche_backlog_burnup.png", width=2000, height=1125, units="px", pointsize=30)

## tranche_burnup=read.csv("/tmp/an_tranche_burnup.csv")
## tranche_burnup$date <- as.Date(tranche_burnup$date, "%Y-%m-%d")
## ##tranche_burnup$points <- tranche_burnup$points - 6850
## tranche_burnup$project2 <- 0 

## ggplot(tranche_backlog) +
##     labs(title="VE backlog by tranche", y="Story Point Total") +
##     theme(text = element_text(size=30), legend.title=element_blank())+
##     geom_area(position='stack', aes(x = date, y = points, group=project2, fill=project2, order=as.numeric(project2))) +
##     scale_x_date(breaks="1 week", label=date_format("%Y-%b-%d"), limits = as.Date(c('2015-06-18', NA))) + 
##     geom_line(data=tranche_burnup, aes(x=date, y=points), size=2)
## dev.off()

## tranche_status=read.csv("/tmp/an_tranche_status.csv")
## tranche_status$date <- as.Date(tranche_status$date, "%Y-%m-%d")

## burnup_tranche_status_output=png(filename = "/tmp/an-tranche_status_burnup.png", width=2000, height=1125, units="px", pointsize=30)
## ggplot(tranche_status) +
##     labs(title="VE backlog by tranche and status", y="Story Point Total") +
##     theme(text = element_text(size=30), legend.title=element_blank())+
##     geom_area(position='stack', aes(x = date, y = points, group=project, fill=project, order=as.numeric(project))) +
##     scale_x_date(breaks="1 month", label=date_format("%Y-%b"), limits = as.Date(c('2015-06-18', NA)))
## dev.off()
