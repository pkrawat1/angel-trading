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
    import("../../vendor/lightweight-charts.standalone.production").then(
      () => {
        this.renderChart();
      }
    )
    this.handleEvent("update-chart", ({
      dataset: data
    }) => {
      data = data[0];
      let candleData = this.candleSeries.data().slice().map(t => Object.assign({}, t));
      let prevData = candleData.pop();
      if (prevData.time == data.time) {
        candleData = candleData.concat(data);
      } else {
        candleData = candleData.concat(prevData, data);
      }
      let calculatedRsi = this.rsi(candleData.map(d => d.close));
      this.candleSeries.update(data);
      this.lineSeries2.update({
        time: data.time,
        value: calculatedRsi.pop()
      });
      this.volumeSeries.update({
        time: data.time,
        value: data.volume
      });
    })
  },
  renderChart() {
    let LightweightCharts = window.LightweightCharts;
    let candleData = JSON.parse(this.el.dataset.series) || [];
    let volumeData = candleData.map(({
      time,
      volume
    }) => ({
      time,
      value: volume
    }));
    // console.error(candleData.slice(0, 20));
    let rsiData = candleData.map(({
      time,
      rsi
    }) => ({
      time,
      value: rsi
    }));
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
      },
    });
    // this.lineSeries = this.chart.addLineSeries({
    // color: 'rgba(4, 111, 232, 1)',
    // lineWidth: 2,
    // priceScaleId: 'right'
    // });
    // this.lineSeries.setData(rsiData);
    this.candleSeries = this.chart.addCandlestickSeries({
      priceScaleId: 'right'
    });
    this.candleSeries.priceScale().applyOptions({
      scaleMargins: {
        // positioning the price scale for the area series
        top: 0,
        bottom: 0.5,
      },
    });
    this.candleSeries.setData(candleData);

    this.lineSeries2 = this.chart.addLineSeries({
      priceFormat: {
        type: 'percent',
      },
      color: 'rgba(4, 111, 232, 1)',
      // color: 'purple',
      lineWidth: 2,
      priceScaleId: 'left'
    });
    this.lineSeries2.priceScale().applyOptions({
      scaleMargins: {
        // positioning the price scale for the area series
        top: 0.5,
        bottom: 0.2,
      },
    });
    let rsiData2 = candleData.map(({
      time,
      close
    }) => ({
      time,
      value: close
    }));
    let calculatedRsi = this.rsi(rsiData2.map(d => d.value));
    rsiData2 = rsiData2.map(({
      time
    }, i) => ({
      time,
      value: calculatedRsi[i]
    }))
    this.lineSeries2.setData(rsiData2);

    this.volumeSeries = this.chart.addHistogramSeries({
      priceFormat: {
        type: 'volume',
      },
      priceScaleId: '', // set as an overlay by setting a blank priceScaleId
      // set the positioning of the volume series
      scaleMargins: {
        top: 0.7, // highest point of the series will be 70% away from the top
        bottom: 0,
      },
    });
    this.volumeSeries.priceScale().applyOptions({
      // set the positioning of the volume series
      scaleMargins: {
        top: 0.8, // highest point of the series will be 70% away from the top
        bottom: 0,
      },
    });
    this.volumeSeries.setData(volumeData);
  },
  destroyed() {
    this.chart.remove();
  },
  /**
   * Rolling moving average (RMA).
   *
   * R[0] to R[p-1] is SMA(values)
   * R[p] and after is R[i] = ((R[i-1]*(p-1)) + v[i]) / p
   *
   * @param period window period.
   * @param values values array.
   * @returns RMA values.
   */
  rma(period, values) {
    const result = new Array(values.length);
    let sum = 0;

    for (let i = 0; i < values.length; i++) {
      let count = i + 1;

      if (i < period) {
        sum += values[i];
      } else {
        sum = result[i - 1] * (period - 1) + values[i];
        count = period;
      }

      result[i] = sum / count;
    }

    return result;
  },
  /**
   * Custom RSI. It is a momentum indicator that measures the magnitude of
   * recent price changes to evaluate overbought and oversold conditions
   * using the given window period.
   *
   * RS = Average Gain / Average Loss
   * RSI = 100 - (100 / (1 + RS))
   *
   * @param period window period.
   * @param closings closing values.
   * @return rsi values.
   */
  customRsi(period, closings) {
    const gains = new Array(closings.length);
    const losses = new Array(closings.length);

    gains[0] = losses[0] = 0;

    for (let i = 1; i < closings.length; i++) {
      const difference = closings[i] - closings[i - 1];

      if (difference > 0) {
        gains[i] = difference;
        losses[i] = 0;
      } else {
        losses[i] = -difference;
        gains[i] = 0;
      }
    }

    const meanGains = this.rma(period, gains);
    const meanLosses = this.rma(period, losses);

    const r = new Array(closings.length);
    const rs = new Array(closings.length);

    r[0] = rs[0] = 0;

    for (let i = 1; i < closings.length; i++) {
      rs[i] = meanGains[i] / meanLosses[i];
      r[i] = 100 - 100 / (1 + rs[i]);
    }
    // console.error(gains.slice(0, 20), losses.slice(0, 20), meanGains.slice(0, 20), meanLosses.slice(0, 20), rs.slice(0, 10), r.slice(0, 10))

    return r;
  },

  /**
   * Relative Strength Index (RSI). It is a momentum indicator that measures
   * the magnitude of recent price changes to evaluate overbought and
   * oversold conditions using the window period of 14.
   *
   * RS = Average Gain / Average Loss
   * RSI = 100 - (100 / (1 + RS))
   *
   * @param closings closing values.
   * @return rsi values.
   */
  rsi(closings) {
    return this.customRsi(14, closings);
  }

}
