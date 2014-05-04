#!/usr/bin/env Rscript
#       user  jobs nodes cores hours     SUs   SUs.q
#   arsamimi     0     0     0     0       0    6080
#       twei     1     5    80    48    3840   11520
#   dissanay     2     8   128    48    3072    1152

data <- read.table('whoscloggin.in', header=T, stringsAsFactors=FALSE)

gen.plot <- function( sorted.data, metric, output.file ) {
    ### filter out empty records
    idx <- sorted.data[,metric] != 0
    sorted.data <- sorted.data[idx,]

    ### figure out what data to actually plot
    ### 1. 9 users + "all others"
    ### 2. exactly 10 users
    ### 3. no users
    n.users <- nrow( sorted.data )
    
    if ( n.users > 10 ) {
        x <- sorted.data[0:9,1]
        y <- sorted.data[0:9,metric]

        # calculate the sum of the remaining users
        y.total <- sum(sorted.data[,metric])
        y.remaining <- y.total - sum(y)

        x <- c( x, 'Other Users' )
        y <- c( y, y.remaining )
        label <- paste( x, ', ', round(y/1000), 'k', sep="")
        color <- rainbow(length(y))

        plot <- data.frame( x, y, label, color, stringsAsFactors=FALSE)

    } else if ( n.users == 0 ) {
        # there are no users to plot
        x <- c( 'No Users' )
        y <- c( 1.0 )
        label <- c( 'No Users' )
        color <- c( rgb( 1, 1, 1, 0 ) )
        plot <- data.frame( x, y, label, color, stringsAsFactors=FALSE)
    } else {
        # plot all the users
        x <- sorted.data[,1]
        y <- sorted.data[,metric]
        label <- paste( x, ', ', round(y/1000), 'k', sep="")
        color <- rainbow(length(y))
        plot <- data.frame( x, y, label, color, stringsAsFactors=FALSE)
    }
    
    ### finally generate the plot
    png(output.file, width=640, height=480, bg='transparent')
    par(new=FALSE, mar=c(0, 0, 0, 0))
    pie(plot$y, labels=plot$label, col=plot$color)
    dev.off()
}

### sorted dataframe
sorted.data <- data[with(data, order(-SUs.q)), ]
gen.plot( sorted.data, 'SUs.q', 'whoscloggin.png' )

### sorted dataframe
sorted.data <- data[with(data, order(-SUs)), ]
gen.plot( sorted.data, 'SUs', 'whosusin.png' )
