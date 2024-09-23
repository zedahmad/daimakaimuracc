var createError = require('http-errors');
var express = require('express');
var path = require('path');
var cookieParser = require('cookie-parser');
var logger = require('morgan');
var cors = require('cors');

var indexRouter = require('./routes/index');
var usersRouter = require('./routes/users');

const SocketProxy = require('./SocketProxy.js');

var app = express();

app.use(logger('dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: false }));
app.use(cookieParser());
app.use(express.static(path.join(__dirname, 'public')));
app.use(cors());

app.use('/', indexRouter);
app.use('/users', usersRouter);

app.set('deathPrice', 1);

// Forward effect IDs to MAME plugin
app.use('/sendData/:id', (req, res, next) => {
  let s = app.get('socketProxy');

  if (s) {
    console.log("Sending " + req.params.id);
	if (req.params.id === '16') {
		let p = app.get('deathPrice');
		
		if (p === 64) {
			app.set('deathPrice', 100);
		} else if (p >= 100) {
			app.set('deathPrice', p + 50);
		} else {
			app.set('deathPrice', p * 2);
		}
	}
    s.proxyRequest(req.params.id);
  }

  res.send("");
})

app.use('/deathprice', (req, res, next) => {
	res.send("" + app.get('deathPrice'));
});

// catch 404 and forward to error handler
app.use(function(req, res, next) {
  next(createError(404));
});

// error handler
app.use(function(err, req, res, next) {
  // set locals, only providing error in development
  res.locals.message = err.message;
  res.locals.error = req.app.get('env') === 'development' ? err : {};

  // render the error page
  res.status(err.status || 500);
  res.render('error');
});

app.set('socketProxy', new SocketProxy(3000));

module.exports = app;
