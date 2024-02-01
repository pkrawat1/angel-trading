export default {
  /*
   * Usage
    <div data-candle="" phx-hook="CandleChart" />
    
    Candle data schema
    [
      { time: '2018-10-19',
        open: 54.62,
        high: 55.50,
        low: 54.52,
        close: 54.90,
        rsi: 50
      },
    ]
  */
  mounted() {
    this.renderChart();
    this.handleEvent("update-chart", ({
      dataset: data
    }) => {
      prevData = this.candleSeries.data().slice().pop();
      data.filter(({
          time
        }) => {
          if (prevData) {
            return time >= prevData.time
          } else {
            console.log("new data")
            return true
          }
        })
        .forEach(item => {
          this.candleSeries.update(item)
          this.lineSeries.update({time: item.time, value: item.rsi})
        })
    })
  },
  renderChart() {
    let LightweightCharts = window.LightweightCharts;
    let candleData = JSON.parse(this.el.dataset.series) || [];
    let rsiData = candleData.filter(({rsi}) => !!rsi).map(({time, rsi}) => ({time, value: rsi}));
    let config = JSON.parse(this.el.dataset.config);
    this.chart = LightweightCharts.createChart(this.el, {
      autoSize: true,
      crosshair: {
        mode: LightweightCharts.CrosshairMode.Normal,
      },
      rightPriceScale: {
        visible: true,
        borderColor: 'rgba(197, 203, 206, 1)',
      },
      leftPriceScale: {
        visible: true,
        borderColor: 'rgba(197, 203, 206, 1)',
      },
      layout: {
        background: {
                type: 'solid',
                color: '#ffffff',
            },
        textColor: 'rgba(33, 56, 77, 1)',
      },
      grid: {
        horzLines: {
          color: '#F0F3FA',
        },
        vertLines: {
          color: '#F0F3FA',
        },
      },
      timeScale: {
        borderColor: 'rgba(197, 203, 206, 1)',
          barSpacing: 10,
          timeVisible: true,
          fitContent: true
      },
      handleScroll: {
        vertTouchDrag: false,
      }
    });
    this.lineSeries = this.chart.addLineSeries({
      color: 'rgba(4, 111, 232, 1)',
      lineWidth: 2,
      priceScaleId: 'left'
    });
    this.lineSeries.setData(rsiData);
    this.candleSeries = this.chart.addCandlestickSeries({
      priceScaleId: 'right'
    });
    this.candleSeries.setData(candleData);
  },
  destroyed() {
    this.chart.remove();
  }

}
