'use strict';

var gulp = require('gulp');
var plugins = require('gulp-load-plugins')();
var del = require('del');

var paths = {
    build: './build/',
    androidPath: '../Android/app/src/main/assets/',
    iosPath: '../iOS/lib/'
};

gulp.task('clean:build', function () {
    return del(paths.build + '*');
});

gulp.task('clean:android', function () {
    return del([paths.androidPath + '*.js', paths.androidPath + '*.html'], { force: true });
});

gulp.task('clean:ios', function () {
    return del([paths.iosPath + '*.js', paths.iosPath + '*.html'], { force: true });
});

gulp.task('clean', ['clean:build', 'clean:android', 'clean:ios']);

gulp.task('index', function () { 
    gulp.src('./src/index.html')
        .pipe(gulp.dest(paths.build))
        .pipe(gulp.dest(paths.androidPath))
        .pipe(gulp.dest(paths.iosPath));
});

// gulp.task('index:debug', function () { 
//     gulp.src('./src/index-debug.html')
//         .pipe(plugins.rename('index.html'))
//         .pipe(gulp.dest(paths.build))
//         .pipe(gulp.dest(paths.androidPath))
//         .pipe(gulp.dest(paths.iosPath));
// });

gulp.task('js', function () { 
    gulp.src('./src/*.js')
        .pipe(plugins.uglify())
        .pipe(gulp.dest(paths.build))
        .pipe(plugins.rename('JSBridge.js'))
        .pipe(gulp.dest(paths.androidPath))
        .pipe(gulp.dest(paths.iosPath));
});

gulp.task('build:android:product', ['js']);
// gulp.task('build:android:debug', ['clean:android', 'index:debug', 'js']);
gulp.task('build:android', ['index', 'js']);

gulp.task('build:ios:product', ['js']);
// gulp.task('build:ios:debug', ['clean:ios', 'index:debug', 'js']);
gulp.task('build:ios', ['index', 'js']);

gulp.task('build:product', ['clean', 'build:android:product', 'build:ios:product']);
gulp.task('build', ['clean', 'build:android', 'build:ios']);

gulp.task('watch', function() {
    gulp.watch(['src/*.js', 'src/*.html'], ['build']);    
});

