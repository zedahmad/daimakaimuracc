import React, { useState, useEffect } from 'react';
import './App.css';
import axios from 'axios';

function App() {
	const [deathPrice, setDeathPrice] = useState(0);

	const sendRequest = (data) => {
		axios.post('http://localhost:3080/sendData/' + data)
			.then(r => console.log("donezo: " + r))
			.catch(e => console.log("yikes" + e));
  	};
  
  	const updateDeathPrice = () => {
	  	axios.get('http://localhost:3080/deathprice')
			.then(r => setDeathPrice(r.data))
			.catch(e => console.log(e))
			.finally(() => {
				setTimeout(updateDeathPrice, 1000);
			});
  	}
	
	useEffect(() => {
		updateDeathPrice();
	}, []);

  return (
    <div className="App">
      <h1>Donation Menu</h1>
	  <div className="item"><span className="price">$1</span><span>Random Weapon</span></div>
	  <div className="item"><span className="price">$2</span><span>Downgrade Armour              </span></div>
	  <div className="item"><span className="price">$2</span><span>Upgrade Armour                </span></div>
	  <div className="item"><span className="price">$2</span><span>Temporary Invincibility       </span></div>
	  <div className="item"><span className="price">$3</span><span>Fast Movement                 </span></div>
	  <div className="item"><span className="price">$3</span><span>Slow Movement                 </span></div>
	  <div className="item"><span className="price">$3</span><span>High Jumps                    </span></div>
	  <div className="item"><span className="price">$3</span><span>Low Jumps                     </span></div>
	  <div className="item"><span className="price">$3</span><span>Low Gravity                   </span></div>
	  <div className="item"><span className="price">$2</span><span>Increase Rank                 </span></div>
	  <div className="item"><span className="price">$2</span><span>Decrease Rank                 </span></div>
	  <div className="item"><span className="price">$5</span><span>Duck Transformation           </span></div>
	  <div className="item"><span className="price">$5</span><span>Old Man Transformation        </span></div>
	  <div className="item death">
		<span className="deathprice">${ deathPrice }</span><span>Death</span>
	  </div>
    </div>
  );
}

export default App;
