import { useState } from "react";
import { Button } from "@mui/material";
import { LoadingButton } from "@mui/lab";
import { createTheme, ThemeProvider } from "@mui/material/styles";
import "../App.css";

const theme = createTheme({
  status: {
    danger: "#fff",
  },
  palette: {
    primary: {
      main: "#fff",
      darker: "#fff",
    },
    neutral: {
      main: "#ffd700",
      contrastText: "#000",
    },
  },
});

const NotLoggedIn = () => {
  const [loading, setLoading] = useState(false);
  const setUpWallet = () => {
    setLoading(true);
  };
  return (
    <div className="App">
      <div id="not-logged-in-content">
        <p className="Header-text">Buy and Sell Amazon Gift Cards!</p>
        <p className="Header-text" style={{ fontSize: 24 }}>
          Powered by Polygon
        </p>
        <ThemeProvider theme={theme}>
          <LoadingButton
            variant="contained"
            color="neutral"
            size="large"
            loading={loading}
            onClick={setUpWallet}
          >
            Enter market
          </LoadingButton>
        </ThemeProvider>
      </div>
    </div>
  );
};

export default NotLoggedIn;
