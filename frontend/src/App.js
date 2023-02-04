import './App.css';
import axios from 'axios';

function App() {
  const sendRequest = (data) => {
    axios.post('http://localhost:3080/sendData/' + data)
        .then(r => console.log("donezo: " + r))
        .catch(e => console.log("yikes" + e));
  };

  return (
    <div className="App">
      <h1>Boy I can't wait to style this trash</h1>
      <button onClick={() => sendRequest(1)}>Random Weapon</button><br />
      <button onClick={() => sendRequest(2)}>Downgrade Armour</button><br />
      <button onClick={() => sendRequest(3)}>Upgrade Armour</button><br />
      <button onClick={() => sendRequest(4)}>Fast Run</button><br />
      <button onClick={() => sendRequest(5)}>Slow Run</button><br />
      <button onClick={() => sendRequest(6)}>High Jump</button><br />
      <button onClick={() => sendRequest(7)}>Low Jump</button><br />
      <button onClick={() => sendRequest(8)}>Duck Transform</button><br />
      <button onClick={() => sendRequest(9)}>Old Transform</button><br />
      <button onClick={() => sendRequest(10)}>Invincibility</button><br />
      <button onClick={() => sendRequest(11)}>Subtract Time</button><br />
      <button onClick={() => sendRequest(12)}>Random Rank</button><br />
      <button onClick={() => sendRequest(13)}>Increase Rank</button><br />
      <button onClick={() => sendRequest(14)}>Decrease Rank</button><br />
      <button onClick={() => sendRequest(15)}>Max Rank</button><br />
      <button onClick={() => sendRequest(16)}>Death</button><br />
      <button onClick={() => sendRequest(17)}>Low Gravity</button><br />
    </div>
  );
}

export default App;
