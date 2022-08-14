import React, { useEffect } from 'react';
import * as anchor from '@project-serum/anchor';
import * as spl from '@solana/spl-token';

import './App.css';
import { ClaimingClientForTest } from './services/claiming/tests/claiming-factory';

const { solana } = window as any;

console.log('App:', { anchor, spl, solana });

const styles: any = {
  section: {
    display: 'flex',
    flexDirection: 'column',
    gap: 10,
  },
  button: {
    padding: '15px 20px',
    cursor: 'pointer',
    minWidth: 150,
  }
}

function App() {
  const testAsOwner = async () => {
    const Test = new ClaimingClientForTest();
    console.log('App test:', { Test });
  }

  const testAsAdmin = async () => {
    const Test = new ClaimingClientForTest();
    console.log('App test:', { Test });
  }

  const testAsUser = async () => {
    const Test = new ClaimingClientForTest();
    console.log('App test:', { Test });
  }

  return (
    <div className="App">
      <header className="App-header">
        <h1>Claiming</h1>
        <h4>(app for testing)</h4>
        <section style={styles.section}>
          <div>
            <button style={styles.button} onClick={testAsOwner}>Test as owner</button>
          </div>
          <div>
            <button style={styles.button} onClick={testAsAdmin}>Test as admin</button>
          </div>
          <div>
            <button style={styles.button} onClick={testAsUser}>Test as user</button>
          </div>
        </section>
      </header>
    </div>
  );
}

export default App;
