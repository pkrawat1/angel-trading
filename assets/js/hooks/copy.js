export default {
  /*
   * Usage
   * <input
      type="hidden"
      id="data-copy"
      value={"Any value"}
    />
    <span data-to="#data-copy" phx-hook="Copy">
      <.icon name="hero-share text-green-700" />
    </span>
  */
  mounted() {
    let { to } = this.el.dataset;
    this.el.addEventListener("click", (ev) => {
      ev.preventDefault();
      let text = document.querySelector(to).value
      navigator.clipboard.writeText(text).then(() => {
        console.log("All done again!")
      })
    });
  },
}
