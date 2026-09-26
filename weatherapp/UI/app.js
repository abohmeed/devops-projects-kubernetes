const express = require('express')
const app = express()
const port = 3000
const path = require('path')
const axios = require('axios')
const cookieParser = require("cookie-parser");
const jwt = require('jsonwebtoken');

// The JWT secret is shared with the auth service and comes from the
// environment (2021 hard-coded it here and in auth).
const jwtSecret = process.env.JWT_SECRET
for (const name of ["JWT_SECRET", "AUTH_HOST", "AUTH_PORT", "WEATHER_HOST", "WEATHER_PORT"]) {
    if (!process.env[name]) {
        console.error(name + " is not set")
        process.exit(1)
    }
}
const authUrl = 'http://' + process.env.AUTH_HOST + ':' + process.env.AUTH_PORT
const weatherUrl = 'http://' + process.env.WEATHER_HOST + ':' + process.env.WEATHER_PORT

app.use('/', express.static(path.join(__dirname, 'public/static')))
app.use(express.urlencoded({extended: true}));
app.use(cookieParser());

function authenticateToken(req, res, next) {
    if (!req.cookies.token) {
        res.redirect("/login");
        return
    }
    jwt.verify(req.cookies.token, jwtSecret, function (err, decoded) {
        if (err) {
            console.log(err.message)
            res.redirect("/login")
            return
        }
        next()
    })
}

app.get("/health", (req, res) => {
    res.sendStatus(200)
})

app.get('/login', (req, res) => {
    res.sendFile(path.join(__dirname, "public", "login.html"))
})
app.get('/signup', (req, res) => {
    res.sendFile(path.join(__dirname, "public", "signup.html"))
})
app.post('/login', (loginreq, loginres) => {
    axios
        .post(authUrl + '/users/' + encodeURIComponent(loginreq.body.username), {
            user_name: loginreq.body.username,
            user_password: loginreq.body.password
        })
        .then((res) => {
            loginres.cookie("token", res.data.JWT, {httpOnly: true, sameSite: "lax"})
            loginres.redirect("/")
        })
        .catch((error) => {
            console.error(error.message)
            loginres.redirect("/login?error=invalidcreds")
        })
})
app.post("/signup", (signupreq, signupres) => {
    axios.post(authUrl + '/users', {
        user_name: signupreq.body.username,
        user_password: signupreq.body.password
    }).then((res) => {
        signupres.redirect("/login")
    }).catch((error) => {
        console.log(error.message)
        signupres.redirect('/signup?error=userexists')
    })
})

app.get('/', authenticateToken, (req, res) => {
    res.sendFile(path.join(__dirname, "public", "index.html"))
})
app.get("/logout", (req, res) => {
    res.clearCookie("token", {httpOnly: true})
    res.redirect("/login")
})
// 2021 never answered the browser when the weather call failed; the error
// (status and message) is now passed through.
app.get("/weather/:city", authenticateToken, (req, res) => {
    axios.get(weatherUrl + '/' + encodeURIComponent(req.params.city))
        .then((response) => {
            res.json(response.data)
        }).catch((error) => {
            console.log(error.message)
            if (error.response) {
                res.status(error.response.status).json(error.response.data)
            } else {
                res.status(502).json({error: "The weather service is unreachable"})
            }
        })
})
app.listen(port, () => {
    console.log(`Weather app listening at http://localhost:${port}`)
})
