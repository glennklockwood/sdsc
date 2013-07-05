#!/usr/bin/env Rscript
# 
#  Glenn K. Lockwood, San Diego Supercomputer Center                    May 2013
#
#  Generate a pretty plot of utilization from the temporally concatenated 
#  output of `nodeview --brief-summary`
#
#  Pretty hacky so far.  Don't expect this to run without modification!
#
################################################################################
#
# first.day.of.data is the day of week on which the data starts (0=Sunday)
# first.hour.of.day is the first hour reported of each day
first.day.of.data <- 3
first.hour.of.day <- 1

args <- commandArgs(TRUE)
system <- args[1]

file.output <- '/tmp'
file.input <- list(
    gordon='/users/u2/glockwood/public_html/status/gordon-ongoing.incl',
    trestles='/users/u2/glockwood/public_html/status/trestles-ongoing.incl' )

headers <- c('time',
            'nodes.tot',
            'cores.tot',
            'jobs.tot',
            'ranks.tot',
            'load.tot',
            'nodes.curr','nodes.max',
            'load.curr','load.max',
            'cores.curr','cores.max',
            'slots.curr','slots.max',
            'mem.curr','mem.max')

if ( system == 'gordon' ) {
    input.data <- read.table(header=F,col.names=headers, 
        file=file.input$gordon)
} else if ( system == 'trestles' ) {
    input.data <- read.table(header=F,col.names=headers, 
        file=file.input$trestles)
} else {
    stop('You must specify system name (gordon or trestles) as a command-line argument')
}

input.data$date <- as.POSIXct(input.data$time,origin='1970-01-01')
input.data$nodes.pct <- input.data$nodes.curr/input.data$nodes.max
input.data$load.pct <- input.data$load.curr / input.data$load.max
input.data$cores.pct <- input.data$cores.curr/input.data$cores.max
input.data$slots.pct <- input.data$slots.curr/input.data$slots.max
input.data$mem.pct <- input.data$mem.curr/input.data$mem.max
# At this point the data is ingested

################################################################################
### Set up data to plot
################################################################################
plot.data.x <- input.data$date
plot.data.data <- list(
    nodes=input.data$nodes.pct,
    load=input.data$load.pct,
    cores=input.data$cores.pct,
    slots=input.data$slots.pct,
    mem=input.data$mem.pct )
file.output = paste(sep='', file.output, '/', system, '-all.png')

plot.legend <- c(  
    'Nodes',
    'Load',
    'Cores',
    'Slots',
    'Mem' )
plot.colors <- c(
    'red',
    'chartreuse3',
    'blue',
    'black',
    'magenta' )

plot.lw <- 2
plot.ylim <- c(0.0,1.0)
plot.cex <- 1.5
plot.ylab <- "Fraction Utilized"

################################################################################
### Plot data
################################################################################
png(file.output, width=640,height=480, bg="transparent")
layout(rbind(1,2),heights=c(7,1))
par(new=F, mar=c(2,6.5,1,0))

plot.new()
for ( i in seq(from=1, to=length(plot.data.data)) ) {
    par(new=T)
    if ( i > 1 ) plot.ylab = ""
    plot(
        x=plot.data.x, 
        y=plot.data.data[[i]],
        type='l',
        lwd=plot.lw,
        col=plot.colors[[i]],
        cex.lab=plot.cex, 
        cex.axis=plot.cex, 
        cex.main=plot.cex, 
        cex.sub=plot.cex,
        xlab="",
        ylab=plot.ylab,
        main="",
        ylim=plot.ylim,
        panel.first=c(abline( h=seq(from=0.0, to=1.0, by=0.1),
        v=seq(plot.data.x[[1]], tail(plot.data.x,1), 86400),
        col='#00000011') )


        )
}

### Shade in the weekends
current.day <- first.day.of.data
current.time <- input.data$time[[1]]
while ( current.time <= tail(input.data$time, 1) ) {
    end.of.day <- current.time + 86400 - 1
    date.begin <- as.POSIXct(current.time - 3600*first.hour.of.day, 
        origin='1970-01-01')
    date.end   <- as.POSIXct(current.time - 3600*first.hour.of.day + 86400, 
        origin='1970-01-01')

    if ( current.day%%7 == 0 | current.day%%7 == 6 ) {
        rect( xleft=date.begin,
              xright=date.end,
              ybottom=0.0,
              ytop=1.0,
              density=100,
              border=NA,
              col='#00000022' )
    }
    current.time <- end.of.day + 1
    current.day <- current.day + 1
}

################################################################################
### Draw the legend in a panel below the main plot
################################################################################
par(mar=c(0,0,0,0))
plot.new()

legend('right',
    legend=plot.legend,
    col=plot.colors,
    lwd=plot.lw,
    bg='transparent',
    cex=plot.cex,
    ncol=5,
    bty='n'
    )

dev.off()
