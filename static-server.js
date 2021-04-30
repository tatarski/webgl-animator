const express = require('express');
const app = express();
const port = process.env.PORT || 8125;
const fs = require('fs');
const bodyParser = require('body-parser');
let formulaList = require('./formulas.json');

app.use(express.static('public'));
app.use(bodyParser.urlencoded({ extended: true }));

app.get('/', (req, res) => {
  res.status(200);
  res.sendFile(`${__dirname}/index.html`);
});


app.get('/list', (req, res) => {
  res.status(200);
  res.send(formulaList);
});
app.post('/formula', (req, res) => {
  let formula = req.body.formula;
  if(formulaList.indexOf(formula) == -1) {
    console.log(formula);
    formulaList.push(formula);
    console.log(formulaList);
    fs.writeFile('formulas.json', JSON.stringify(formulaList), 'utf8', (err)=>{
      if(err) {
        console.log(err);
      }else{
        console.log("New formula added to DB");
      }
    });
  }
  res.status(200);
  res.end();
});

app.listen(port, () => {
  console.log(`Listening at PORT:${port}`);
});
