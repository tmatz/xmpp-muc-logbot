var app = angular.module('app', ['ngRoute', 'ui.bootstrap']);

app.controller('RoomCtrl', function($scope) {
  $scope.title = 'title';
  $scope.oneAtTime = true;
  $scope.rooms = [
    { title: 'Room 1', contents: 'aaa' },
    { title: 'Room 2', contents: '000' },
    { title: 'Room 3', contents: 'xxx' }
  ];
  $scope.messages = [];
  $scope.status = {
    isFirstOpen: true,
    isFirstDisabled: false
  };
});
