const express = require('express');
const app = express();
app.get('/', (req, res) => res.send('EM Service Ready'));
app.listen(3000, () => console.log('EM running on 3000'));