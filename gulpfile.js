var gulp = require('gulp');
var protractor = require("gulp-protractor").protractor;
var reporter = require("gulp-protractor-cucumber-html-report");

gulp.task("execute",function () {
        return gulp.src([])
            .pipe(protractor({
                configFile: "conf.js"
            }))
            .on('error', function(e) { throw e })
    }
);
 
gulp.task("report", function () {
    gulp.src("reports/results.json")
        .pipe(reporter({
            dest: "reports"
        }));
});