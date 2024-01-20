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
        close: 54.90
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
          console.log(item)
          this.candleSeries.update(item)
        })
    })
  },
  renderChart() {
    let LightweightCharts = window.LightweightCharts;
    let data = JSON.parse(this.el.dataset.series) || [];
    let config = JSON.parse(this.el.dataset.config);
    this.chart = LightweightCharts.createChart(this.el, {
      autoSize: true,
      crosshair: {
        mode: LightweightCharts.CrosshairMode.Normal,
      },
    });
    this.chart.timeScale().applyOptions({
      barSpacing: 10,
      timeVisible: true
    });
    this.candleSeries = this.chart.addCandlestickSeries();
    this.candleSeries.setData(data);
  },
  destroyed() {
    this.chart.remove();
  }

}
