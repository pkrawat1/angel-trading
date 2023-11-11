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
    let LightweightCharts = window.LightweightCharts;
    let data = JSON.parse(this.el.dataset.candle);
    let chart = LightweightCharts.createChart(this.el, {
      autoSize: true,
      crosshair: {
        mode: LightweightCharts.CrosshairMode.Normal,
      },
    });
    let candleSeries = chart.addCandlestickSeries();
    candleSeries.setData(data);
    console.log(data);
  },
}
