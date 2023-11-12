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
  },
  updated() {
    this.renderChart();
  },
  renderChart() {
    let LightweightCharts = window.LightweightCharts;
    let data = JSON.parse(this.el.dataset.candle);
    if(this.chart) {
      this.chart.remove();
      // prevData = this.candleSeries.data().slice().pop();
      // data.filter(({time}) => time > prevData.time)
          // .forEach(item => this.candleSeries.update(item))
      // return;
    }
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
  }

}
