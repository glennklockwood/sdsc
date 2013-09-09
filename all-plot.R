#!/usr/bin/env Rscript
# 
#  Glenn K. Lockwood, San Diego Supercomputer Center                 August 2013
#
#  Generate a pretty plot of utilization from the temporally concatenated 
#  output of `nodeview --brief-summary`
#
################################################################################

args <- commandArgs(TRUE)
system <- args[1]

file.output <- './'
file.input <- list(
    gordon='gordon-ongoing.incl',
    trestles='trestles-ongoing.incl' )

compute.headers <- c('time',
            'nodes.tot',
            'cores.tot',
            'jobs.tot',
            'ranks.tot',
            'load.tot',
            'nodes.curr','nodes.max',
            'load.curr','load.max',
            'cores.curr','cores.max',
            'slots.curr','slots.max',
            'mem.curr','mem.max',
            'proj.max','proj.curr',
            'scratch.max','scratch.curr')

if ( system == 'gordon' ) {
    compute.data <- read.table(header=F,col.names=compute.headers, 
        file=file.input$gordon)
} else if ( system == 'trestles' ) {
    compute.data <- read.table(header=F,col.names=compute.headers, 
        file=file.input$trestles)
} else {
    stop('You must specify system name (gordon or trestles) as a command-line argument')
}

compute.data$date <- as.POSIXct(compute.data$time,origin='1970-01-01')
compute.data$nodes.pct <- compute.data$nodes.curr/compute.data$nodes.max
compute.data$load.pct <- compute.data$load.curr / compute.data$load.max
compute.data$cores.pct <- compute.data$cores.curr/compute.data$cores.max
compute.data$slots.pct <- compute.data$slots.curr/compute.data$slots.max
compute.data$mem.pct <- compute.data$mem.curr/compute.data$mem.max
compute.data$proj.pct <- compute.data$proj.curr/compute.data$proj.max
compute.data$scratch.pct <- compute.data$scratch.curr/compute.data$scratch.max
# At this point the data is ingested

################################################################################
### Set up data to plot
################################################################################
tmp.compute.xvec <- (compute.data$date > (tail(compute.data$date, n=1) - 760*3600))
plot.data.x <- compute.data$date[tmp.compute.xvec]
plot.data.y <- list(
    nodes=  compute.data$nodes.pct[tmp.compute.xvec],
    load=   compute.data$load.pct[tmp.compute.xvec],
    cores=  compute.data$cores.pct[tmp.compute.xvec],
    slots=  compute.data$slots.pct[tmp.compute.xvec],
    mem=    compute.data$mem.pct[tmp.compute.xvec],
    proj=   compute.data$proj.pct[tmp.compute.xvec],
    scratch=compute.data$scratch.pct[tmp.compute.xvec] )
file.output = paste(sep='', file.output, '/', system, '-all.png')

plot.legend <- c(  
    'Availability',
    'CPU Load',
    'Cores Req\'d',
    'Utilization',
    'Memory Used',
    'Oasis Proj',
    'Oasis Scratch'
    )
plot.colors <- c(
    '#E41A1C',
    '#377EB8',
    '#4DAF4A',
    '#984EA3',
    '#FF7F00',
    '#F781BF',
    '#A65628' )
plot.ltys <- c(
    'solid',
    'solid',
    'solid',
    'solid',
    'solid',
    'dotted',
    'dotted' )
plot.lws<- c(
    2,
    2,
    2,
    2,
    2,
    4,
    4 )

plot.ylim <- c(0.0,1.0)
plot.cex <- 1.5
plot.ylab <- "Fraction Utilized"

### determine day boundaries so the plot's gridlines will match up
plot.data.firstday <- as.POSIXlt(plot.data.x[[1]])
plot.data.firstday$sec <- 0
plot.data.firstday$min <- 0
plot.data.firstday$hour <- 0
plot.data.lastday <- as.POSIXlt(tail(plot.data.x,1))
plot.data.lastday$sec <- 0
plot.data.lastday$min <- 0
plot.data.lastday$hour <- 0

################################################################################
### Plot data
################################################################################
png(file.output, width=640,height=480, bg="transparent")
layout(rbind(1,2),heights=c(7,1))
par(new=F, mar=c(2, 6.5, 1, 2))

plot.new()
for ( i in seq(from=1, to=length(plot.data.y)) ) {
    par(new=T)
    if ( i > 1 ) plot.ylab = ""
    plot(
        x=plot.data.x,
        y=plot.data.y[[i]],
        type='l',
        lwd=plot.lws[[i]],
        lty=plot.ltys[[i]],
        col=plot.colors[[i]],
        cex.lab=plot.cex, 
        cex.axis=plot.cex, 
        cex.main=plot.cex, 
        cex.sub=plot.cex,
        xlab="",
        ylab=plot.ylab,
        main="",
        ylim=plot.ylim,
        ### draw grid aligned to days (86400 seconds)
        panel.first=c(abline( 
            h=seq(from=0.0, to=1.0, by=0.1),
            v=seq(as.POSIXct(plot.data.firstday)+86400, 
                  as.POSIXct(plot.data.lastday) -86000, 86400),
        col='#00000011') )
        )
}

### Find data points falling on weekends (Saturday and Sunday)
plot.data.isweekend <- sapply(X=plot.data.x, FUN=function(x) { 
    xx = as.POSIXlt(x)
    if ( xx$wday == 0 || xx$wday == 6 ) { 
        return(TRUE)
    } 
    else { 
        return(FALSE)
    } 
})

### Shade in the weekends
is.weekend = 0
weekend.start = 1
for ( i in seq(1, length(plot.data.x) ) ) {
    if ( plot.data.isweekend[[i]] && !is.weekend ) {
        weekend.start = i
        is.weekend = 1
    }
    else if ( !plot.data.isweekend[[i]] && is.weekend ) {
        rect( xleft=plot.data.x[[weekend.start]],
            xright=plot.data.x[[i-1]],
            ybottom=0.0,
            ytop=1.0,
            density=100,
            border=NA,
            col='#00000022' )
        is.weekend = 0
    }
}
### if the data ends on a weekend, draw that last box
if ( tail(plot.data.isweekend, n=1) && weekend.start > 1 ) {
    rect( xleft=plot.data.x[[weekend.start]],
        xright=tail(plot.data.x,n=1),
        ybottom=0.0,
        ytop=1.0,
        density=100,
        border=NA,
        col='#00000022' )
}

################################################################################
### Draw the legend in a panel below the main plot
################################################################################
par(mar=c(0,0,0,0))
plot.new()

legend('right',
    legend=plot.legend,
    col=plot.colors,
    lwd=plot.lws,
    lty=plot.ltys,
    bg='transparent',
    cex=plot.cex,
    ncol=3,
    bty='n'
    )

dev.off()
