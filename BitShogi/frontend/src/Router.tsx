import { BrowserRouter, Routes, Route } from 'react-router-dom';
import App from './App';
import Rules from './Rules';
import Bots from './Bots';

function Router() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<App />} />
        <Route path="/rules" element={<Rules />} />
        <Route path="/bots" element={<Bots />} />
      </Routes>
    </BrowserRouter>
  );
}

export default Router;
