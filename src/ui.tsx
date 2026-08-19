import "@/index.css";

import { React, ReactDOM } from "@/lib/shiny";
import App from "@/App";

const container = document.getElementById("root");
if (!container) {
  throw new Error("No #root in www/index.html to mount into.");
}

ReactDOM.createRoot(container).render(React.createElement(App));
