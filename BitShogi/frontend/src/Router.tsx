import { BrowserRouter, Routes, Route } from 'react-router-dom';
import App from './App';
import Rules from './Rules';

function Router() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<App />} />
        <Route path="/rules" element={<Rules />} />
      </Routes>
    </BrowserRouter>
  );
}

export default Router;
