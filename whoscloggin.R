#!/usr/bin/env Rscript
#       user  jobs nodes cores hours     SUs   SUs.q
#   arsamimi     0     0     0     0       0    6080
#       twei     1     5    80    48    3840   11520
#   dissanay     2     8   128    48    3072    1152

data <- read.table('whoscloggin.in', header=T, stringsAsFactors=FALSE)

max.n.plot <- 8

plot.colors <- c( '#A6CEE3', '#1F78B4', '#B2DF8A', '#33A02C', '#FB9A99',
                  '#E31A1C', '#FDBF6F', '#FF7F00', '#CAB2D6', '#6A3D9A')
plot.colors <- c( '#8DD3C7', '#FFFFB3', '#BEBADA', '#FB8072', '#80B1D3',
                  '#FDB462', '#B3DE69', '#FCCDE5', '#D9D9D9', '#BC80BD')
plot.colors <- c( '#E41A1C', '#377EB8', '#4DAF4A', '#984EA3', '#FF7F00',
                  '#FFFF33', '#A65628', '#F781BF', '#999999' )

gen.plot <- function( sorted.data, metric, output.file ) {
    ### filter out empty records
    idx <- sorted.data[,metric] != 0
    sorted.data <- sorted.data[idx,]

    ### figure out what data to actually plot
    ### 1. 9 users + "all others"
    ### 2. exactly 10 users
    ### 3. no users
    n.users <- nrow( sorted.data )
    
    if ( n.users > (max.n.plot+1) ) {
        x <- sorted.data[0:max.n.plot,1]
        y <- sorted.data[0:max.n.plot,metric]

        # calculate the sum of the remaining users
        y.total <- sum(sorted.data[,metric])
        y.remaining <- y.total - sum(y)

        x <- c( x, 'Other Users' )
        y <- c( y, y.remaining )
        label <- paste( x, ', ', round(y/1000), 'k', sep="")
#       color <- rainbow(length(y))
        color <- plot.colors[0:length(y)]

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
#       color <- rainbow(length(y))
        color <- plot.colors[0:length(y)]
        plot <- data.frame( x, y, label, color, stringsAsFactors=FALSE)
    }
    
    ### finally generate the plot
    png(output.file, width=640, height=480, bg='transparent')
    par(new=FALSE, mar=c(0, 0, 0, 0))
    pie(plot$y, labels=plot$label, col=plot$color, cex=1.75)
    dev.off()
}

### sorted dataframe
sorted.data <- data[with(data, order(-SUs.q)), ]
gen.plot( sorted.data, 'SUs.q', 'whoscloggin.png' )

### sorted dataframe
sorted.data <- data[with(data, order(-SUs)), ]
gen.plot( sorted.data, 'SUs', 'whosusin.png' )
