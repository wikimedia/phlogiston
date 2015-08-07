## Convert a historical transaction file from Phab into a burnup report

library(reshape2)
library(ggplot2)
library(scales)
library(grid)

######################################################################
## VisualEditor Status
######################################################################

ve_status=read.csv("/tmp/ve_status.csv")
ve_status$date <- as.Date(ve_status$date, "%Y-%m-%d")

ve_status_output=png(filename = "/tmp/ve-backlog-status.png", width=2000, height=1125, units="px", pointsize=30)
    
ggplot(ve_status) +
    labs(title="Disposition of the ve backlog", y="Story Point Total") +
    theme(text = element_text(size=30), legend.title=element_blank())+
    geom_area(position='stack', aes(x = date, y = points, group=status, fill=status, order=-as.numeric(status))) +
    scale_x_date(breaks="1 month", label=date_format("%Y-%b"), limits = as.Date(c('2014-12-01', NA))) +
    scale_y_continuous(limits=c(0, 30000))
dev.off()

######################################################################
## Backlog
######################################################################

backlog=read.csv("/tmp/ve_backlog.csv")
backlog$date <- as.Date(backlog$date, "%Y-%m-%d")
## manually set ordering of data
backlog$project2 <- factor(backlog$project, levels = c("VisualEditor General Backlog","TR4: Link editor tweaks", "TR3: Language support", "TR2: Mobile MVP", "TR1: Releases","VisualEditor 2014/15 Q4 blockers","VisualEditor 2014/15 Q3 blockers","VisualEditor Interrupt"))

burnup=read.csv("/tmp/ve_burnup.csv")
burnup$date <- as.Date(burnup$date, "%Y-%m-%d")
burnup$project2 <- 0 ## dummy colum so it fits on the same ggplot
burnup_output=png(filename = "/tmp/ve-backlog_burnup.png", width=2000, height=1125, units="px", pointsize=30)
    
ggplot(backlog) +
    labs(title="VE backlog", y="Story Point Total") +
    theme(text = element_text(size=30), legend.title=element_blank())+
    geom_area(position='stack', aes(x = date, y = points, group=project2, fill=project2, order=-as.numeric(project2))) +
    scale_x_date(breaks="1 month", label=date_format("%Y-%b"), limits = as.Date(c('2014-12-01', NA))) +
    scale_y_continuous(limits=c(0, 30000)) +
        geom_line(data=burnup, aes(x=date, y=points), size=2)
dev.off()

######################################################################
## Cropped backlog

burnup_crop_output=png(filename = "/tmp/ve-backlog_burnup_crop.png", width=2000, height=1125, units="px", pointsize=30)
    
ggplot(backlog) +
    labs(title="VE backlog (zoomed)", y="Story Point Total") +
    theme(text = element_text(size=30), legend.title=element_blank()) +
    geom_area(position='stack', aes(x = date, y = points, group=project2, fill=project2, order=-as.numeric(project2))) +
    scale_x_date(breaks="1 month", label=date_format("%Y-%b"), limits = as.Date(c('2015-02-01', NA))) +
    scale_y_continuous(limits=c(0, 10000)) +
    geom_line(data=burnup, aes(x=date, y=points), size=2)
dev.off()


######################################################################
## TR0

tr_burnup=read.csv("/tmp/ve_TR0.csv")
tr_burnup$date <- as.Date(tr_burnup$date, "%Y-%m-%d")
burnup_output=png(filename = "/tmp/ve-tranch0_burnup.png", width=2000, height=1125, units="px", pointsize=30)

par(las=3)
ggplot(tr_burnup) + 
    labs(title="VE Interruptions (Tranche 0)", y="Story Point Total") +
    theme(text = element_text(size=30), legend.title=element_blank())+
    geom_area(position='stack', aes(x = date, y = points, group=status, fill=status, order=-as.numeric(status))) +
    scale_x_date(breaks="1 week", label=date_format("%Y-%b-%d"), limits = as.Date(c('2015-06-18', NA))) +
    scale_y_continuous(limits=c(0, 800)) 
dev.off()

######################################################################
## TR1

tr_burnup=read.csv("/tmp/ve_TR1.csv")
tr_burnup$date <- as.Date(tr_burnup$date, "%Y-%m-%d")
burnup_output=png(filename = "/tmp/ve-tranch1_burnup.png", width=2000, height=1125, units="px", pointsize=30)
    
ggplot(tr_burnup) +
    labs(title="VE Tranch 1 backlog", y="Story Point Total") +
    theme(text = element_text(size=30), legend.title=element_blank())+
    geom_area(position='stack', aes(x = date, y = points, group=status, fill=status, order=-as.numeric(status))) +
    scale_x_date(breaks="1 week", label=date_format("%Y-%b-%d"), limits = as.Date(c('2015-06-18', NA))) +
    scale_y_continuous(limits=c(0, 800)) 
dev.off()

######################################################################
## TR2

tr_burnup=read.csv("/tmp/ve_TR2.csv")
tr_burnup$date <- as.Date(tr_burnup$date, "%Y-%m-%d")
burnup_output=png(filename = "/tmp/ve-tranch2_burnup.png", width=2000, height=1125, units="px", pointsize=30)
    
ggplot(tr_burnup) +
    labs(title="VE Tranch 2 backlog", y="Story Point Total") +
    theme(text = element_text(size=30), legend.title=element_blank())+
    geom_area(position='stack', aes(x = date, y = points, group=status, fill=status, order=-as.numeric(status))) +
    scale_x_date(breaks="1 week", label=date_format("%Y-%b-%d"), limits = as.Date(c('2015-06-18', NA))) +
    scale_y_continuous(limits=c(0, 800)) 
dev.off()

######################################################################
## TR3

tr_burnup=read.csv("/tmp/ve_TR3.csv")
tr_burnup$date <- as.Date(tr_burnup$date, "%Y-%m-%d")
burnup_output=png(filename = "/tmp/ve-tranch3_burnup.png", width=2000, height=1125, units="px", pointsize=30)
    
ggplot(tr_burnup) +
    labs(title="VE Tranch 3 backlog", y="Story Point Total") +
    theme(text = element_text(size=30), legend.title=element_blank())+
    geom_area(position='stack', aes(x = date, y = points, group=status, fill=status, order=-as.numeric(status))) +
    scale_y_continuous(limits=c(0, 800)) 
dev.off()

######################################################################
## TR4

tr_burnup=read.csv("/tmp/ve_TR4.csv")
tr_burnup$date <- as.Date(tr_burnup$date, "%Y-%m-%d")
burnup_output=png(filename = "/tmp/ve-tranch4_burnup.png", width=2000, height=1125, units="px", pointsize=30)
    
ggplot(tr_burnup) +
    labs(title="VE Tranch 4 backlog", y="Story Point Total") +
    theme(text = element_text(size=30), legend.title=element_blank())+
    geom_area(position='stack', aes(x = date, y = points, group=status, fill=status, order=-as.numeric(status))) +
    scale_y_continuous(limits=c(0, 800)) 
dev.off()

######################################################################
## TR5

tr_burnup=read.csv("/tmp/ve_TR5.csv")
tr_burnup$date <- as.Date(tr_burnup$date, "%Y-%m-%d")
burnup_output=png(filename = "/tmp/ve-tranch5_burnup.png", width=2000, height=1125, units="px", pointsize=30)
    
ggplot(tr_burnup) +
    labs(title="VE Tranch 5 backlog", y="Story Point Total") +
    theme(text = element_text(size=30), legend.title=element_blank())+
    geom_area(position='stack', aes(x = date, y = points, group=status, fill=status, order=-as.numeric(status))) +
    scale_y_continuous(limits=c(0, 800)) 
dev.off()


######################################################################
## Interrupt
######################################################################

veinterrupt=read.csv("/tmp/ve_interrupt.csv")
veinterrupt$date <- as.Date(veinterrupt$date, "%Y-%m-%d")

status_output=png(filename = "/tmp/ve-interrupt.png", width=2000, height=1125, units="px", pointsize=30)
    
ggplot(veinterrupt) +
    labs(title="Capacity and Interrupt", y="Story Point Total") +
    theme(text = element_text(size=30), legend.title=element_blank()) +
    geom_area(position='stack', aes(x = date, y = points)) +
    scale_fill_manual(values=c("red", "green")) +           
    scale_x_date(breaks="1 month", label=date_format("%Y-%b"), limits = as.Date(c('2014-12-01', NA))) +
    scale_y_continuous(limits=c(0, 15000)) +
    geom_line(data=burnup, aes(x=date, y=points), size=2)
dev.off()

######################################################################
## Velocity
######################################################################

velocity=read.csv("/tmp/ve_velocity.csv")
velocity$week <- as.Date(velocity$week, "%Y-%m-%d")

velocity_output=png(filename = "/tmp/ve-velocity.png", width=2000, height=1125, units="px", pointsize=30)

ggplot(velocity, aes(week, velocity)) +
    labs(title="Velocity per week", y="Story Points") +
        geom_bar(stat="identity")
dev.off()

######################################################################
## Velocity vs backlog
######################################################################

net_growth=read.csv("/tmp/ve_net_growth.csv")
net_growth$date <- as.Date(net_growth$date, "%Y-%m-%d")

net_growth_output=png(filename = "/tmp/ve-net_growth.png", width=2000, height=1125, units="px", pointsize=30)

ggplot() +
    labs(title="Net change in open backlog", y="Story Points") +
    theme(text = element_text(size=30), legend.title=element_blank())+
    geom_line(data = net_growth, stat="identity", aes(date, points), size=2)
dev.off()

##histogram_output=png(filename = "/tmp/ve-histogram.png", width=2000, height=1125, units="px", pointsize=30)
##point_hist=read.csv("/tmp/histogram.csv");
##point_hist_wide <- dcast(point <- hist, points + project ~ category, value.var="count")
## ggplot(phab_summ, aes(x = Date, y = points, group=points, fill=Project)) + geom_area(position='stack')
## phab_summ_t = dcast(phab_summ, Date ~ Project)
## velocity = group_by(phab_data, Date, Status)
## velocity = summarize(velocity, points = sum(Points))
## velocityT = dcast(velocity, Date ~ Status)
## write.csv(VelocityT, file="velocity.csv")
## write.csv(phab_summ_t, file="backlog.csv")

######################################################################
## Tranche Backlog
######################################################################

tranche_backlog=read.csv("/tmp/ve_tranche_backlog.csv")

## Backlog

tranche_backlog$date <- as.Date(tranche_backlog$date, "%Y-%m-%d")
tranche_backlog$project2 <- factor(tranche_backlog$project, levels = c("VisualEditor TR0: Interrupt", "VisualEditor TR1: Releases", "VisualEditor TR2: Mobile MVP", "VisualEditor TR3: Language support", "VisualEditor TR4: Link editor tweaks"))

burnup_tranche_output=png(filename = "/tmp/ve-tranche_backlog_burnup.png", width=2000, height=1125, units="px", pointsize=30)

tranche_burnup=read.csv("/tmp/ve_tranche_burnup.csv")
tranche_burnup$date <- as.Date(tranche_burnup$date, "%Y-%m-%d")
##tranche_burnup$points <- tranche_burnup$points - 6850
tranche_burnup$project2 <- 0 

ggplot(tranche_backlog) +
    labs(title="VE backlog by tranche", y="Story Point Total") +
    theme(text = element_text(size=30), legend.title=element_blank())+
    geom_area(position='stack', aes(x = date, y = points, group=project2, fill=project2, order=as.numeric(project2))) +
    scale_x_date(breaks="1 week", label=date_format("%Y-%b-%d"), limits = as.Date(c('2015-06-18', NA))) + 
    geom_line(data=tranche_burnup, aes(x=date, y=points), size=2)
dev.off()

tranche_status=read.csv("/tmp/ve_tranche_status.csv")
tranche_status$date <- as.Date(tranche_status$date, "%Y-%m-%d")

burnup_tranche_status_output=png(filename = "/tmp/ve-tranche_status_burnup.png", width=2000, height=1125, units="px", pointsize=30)
ggplot(tranche_status) +
    labs(title="VE backlog by tranche and status", y="Story Point Total") +
    theme(text = element_text(size=30), legend.title=element_blank())+
    geom_area(position='stack', aes(x = date, y = points, group=project, fill=project, order=as.numeric(project))) +
    scale_x_date(breaks="1 month", label=date_format("%Y-%b"), limits = as.Date(c('2015-06-18', NA)))
dev.off()

######################################################################
## Lead Time
######################################################################

leadtime=read.csv("/tmp/ve_leadtime.csv")
leadtime$week <- as.Date(leadtime$week, "%Y-%m-%d")
leadtime_output=png(filename = "/tmp/ve-leadtime.png", width=2000, height=1125, units="px", pointsize=30)
ggplot(leadtime, aes(x=week, y=points, fill=leadtime)) +
    labs(title="VE Lead Time for resolved tasks", y="Story Point Total") +
    geom_bar(stat="identity")
dev.off()

histopoints=read.csv("/tmp/ve_histopoints.csv")
histopoints$week <- as.Date(histopoints$week, "%Y-%m-%d")
histopoints_output=png(filename = "/tmp/ve-histopoints.png", width=2000, height=1125, units="px", pointsize=30)
ggplot(histopoints, aes(x=week, y=sumpoints, fill=factor(points))) +
    labs(title="VE Age of backlog (by points)", y="Story Point Total") +
    geom_bar(stat="identity")
dev.off()

histocount=read.csv("/tmp/ve_histocount.csv")
histocount$week <- as.Date(histocount$week, "%Y-%m-%d")
histocount_output=png(filename = "/tmp/ve-histocount.png", width=2000, height=1125, units="px", pointsize=30)
ggplot(histocount, aes(x=week, y=count, fill=factor(points))) +
    labs(title="VE Age of backlog (by count)", y="Count") +
    geom_bar(stat="identity")
dev.off()

backlogage=read.csv("/tmp/ve_backlogage.csv")
backlogage$week <- as.Date(backlogage$week, "%Y-%m-%d")
backlogage_output=png(filename = "/tmp/ve-backlogage.png", width=2000, height=1125, units="px", pointsize=30)
ggplot(backlogage, aes(x=week, y=points, fill=backlogage)) +
    labs(title="Age of VE backlog (open tasks)", y="Story Point Total") +
    geom_bar(stat="identity")
dev.off()
